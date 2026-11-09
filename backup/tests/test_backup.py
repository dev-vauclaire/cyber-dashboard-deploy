"""Exercise backup and retention with synthetic archives and local command doubles.

Run from the deployment repository with:
    python3 -B -m unittest discover -s backup/tests -v
"""

from datetime import datetime, timedelta, timezone
import fcntl
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "script.sh"
ARCHIVE_PREFIX = "cyber-dashboard-postgresql_"


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cyber-backup-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / "project"
        self.project.mkdir()
        (self.project / "docker-compose.yaml").write_text("services: {}\n")
        self.mount = self.root / "nfs"
        self.mount.mkdir()
        self.archives = self.mount / "postgresql"
        self.lock = self.root / "backup.lock"
        self.docker_log = self.root / "docker.log"
        self.dump_finished = self.root / "dump-finished"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.environment = {
            "PROJECT_DIR": str(self.project),
            "BACKUP_MOUNT": str(self.mount),
            "LOCK_FILE": str(self.lock),
            "FAKE_DOCKER_LOG": str(self.docker_log),
            "FAKE_DUMP_STATE": str(self.dump_finished),
            "PATH": f"{self.bin}:/usr/bin:/bin",
        }
        self._command(
            "mountpoint",
            """
            #!/usr/bin/env python3
            import os
            from pathlib import Path
            import sys
            lost = os.environ.get("FAKE_LOSE_MOUNT_AFTER_DUMP") == "1" and Path(os.environ["FAKE_DUMP_STATE"]).exists()
            sys.exit(1 if os.environ.get("FAKE_NO_MOUNT") == "1" or lost else 0)
            """,
        )
        self._command(
            "findmnt",
            """
            #!/usr/bin/env python3
            import os
            from pathlib import Path
            import sys
            lost = os.environ.get("FAKE_LOSE_MOUNT_AFTER_DUMP") == "1" and Path(os.environ["FAKE_DUMP_STATE"]).exists()
            if os.environ.get("FAKE_NO_MOUNT") == "1" or lost:
                sys.exit(1)
            if os.environ.get("FAKE_NOT_NFS") == "1":
                if any("nfs" in arg for arg in sys.argv[1:]):
                    sys.exit(1)
                print("ext4")
            else:
                print("nfs4")
            """,
        )
        self._command(
            "docker",
            """
            #!/usr/bin/env python3
            import os
            from pathlib import Path
            import sys
            arguments = " ".join(sys.argv[1:])
            if "pg_dump" in arguments:
                operation = "dump"
            elif "pg_restore" in arguments:
                operation = "restore"
            elif "pg_isready" in arguments:
                operation = "ready"
            else:
                operation = "unexpected"
            with Path(os.environ["FAKE_DOCKER_LOG"]).open("a") as log:
                log.write(operation + "\\n")
            if operation == "dump":
                if os.environ.get("FAKE_DUMP_FAIL") == "1":
                    sys.stdout.buffer.write(b"INCOMPLETE")
                    sys.exit(1)
                content = b"BAD synthetic archive" if os.environ.get("FAKE_DUMP_INVALID") == "1" else b"GOOD synthetic archive"
                sys.stdout.buffer.write(content)
                Path(os.environ["FAKE_DUMP_STATE"]).touch()
            elif operation == "restore":
                content = sys.stdin.buffer.read()
                sys.exit(0 if content.startswith(b"GOOD") else 1)
            elif operation == "ready":
                sys.exit(0)
            else:
                sys.stderr.write("Unexpected fake Docker operation\\n")
                sys.exit(2)
            """,
        )

    def _command(self, name, source):
        path = self.bin / name
        path.write_text(textwrap.dedent(source).lstrip())
        path.chmod(0o755)

    def _archive(self, days_ago, content=b"GOOD previous synthetic archive"):
        timestamp = datetime.now(timezone.utc) - timedelta(days=days_ago)
        return self._archive_at(timestamp, content)

    def _archive_at(self, timestamp, content=b"GOOD previous synthetic archive"):
        self.archives.mkdir(exist_ok=True)
        name = f"{ARCHIVE_PREFIX}{timestamp:%Y%m%dT%H%M%SZ}.dump"
        path = self.archives / name
        path.write_bytes(content)
        return path

    def _freeze_time(self, now, completed=None):
        self.environment["FAKE_NOW"] = str(int(now.timestamp()))
        self.environment["FAKE_COMPLETED_NOW"] = str(
            int((completed or now).timestamp())
        )
        self._command(
            "date",
            """
            #!/usr/bin/env python3
            import os
            from pathlib import Path
            import sys
            arguments = sys.argv[1:]
            if "+%s" in arguments and not any(argument.startswith("--date") for argument in arguments):
                key = "FAKE_COMPLETED_NOW" if Path(os.environ["FAKE_DUMP_STATE"]).exists() else "FAKE_NOW"
                print(os.environ[key])
            else:
                os.execve("/usr/bin/date", ["/usr/bin/date", *arguments], {"LC_ALL": "C", "PATH": "/usr/bin:/bin"})
            """,
        )

    def _run(self, *arguments, **changes):
        environment = self.environment | changes
        return subprocess.run(
            ["bash", str(SCRIPT), *arguments],
            env=environment,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

    def _assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)

    def _assert_failure(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def _files(self):
        return set(self.archives.iterdir()) if self.archives.exists() else set()

    def test_missing_mount_fails_without_creating_backup_directory(self):
        result = self._run(FAKE_NO_MOUNT="1")
        self._assert_failure(result)
        self.assertFalse(self.archives.exists())
        self.assertFalse(self.docker_log.exists())

    def test_non_nfs_mount_is_rejected(self):
        result = self._run(FAKE_NOT_NFS="1")
        self._assert_failure(result)
        self.assertFalse(self.archives.exists())
        self.assertFalse(self.docker_log.exists())

    def test_mount_loss_after_dump_preserves_existing_archives(self):
        previous = {self._archive(days) for days in (12, 8, 4)}
        result = self._run(FAKE_LOSE_MOUNT_AFTER_DUMP="1")
        self._assert_failure(result)
        self.assertTrue(self.dump_finished.exists())
        self.assertEqual(self._files(), previous)
        self.assertTrue(all(path.read_bytes().startswith(b"GOOD") for path in previous))

    def test_symlink_backup_directory_is_rejected_without_writing_target(self):
        target = self.root / "unrelated-directory"
        target.mkdir()
        sentinel = target / "keep.txt"
        sentinel.write_text("synthetic file to preserve")
        self.archives.symlink_to(target, target_is_directory=True)
        result = self._run()
        self._assert_failure(result)
        self.assertTrue(self.archives.is_symlink())
        self.assertEqual(set(target.iterdir()), {sentinel})
        self.assertEqual(sentinel.read_text(), "synthetic file to preserve")
        self.assertFalse(self.docker_log.exists())

    def test_success_publishes_one_timestamped_archive(self):
        result = self._run()
        self._assert_success(result)
        files = self._files()
        self.assertEqual(len(files), 1)
        archive = files.pop()
        self.assertRegex(
            archive.name,
            rf"^{ARCHIVE_PREFIX}[0-9]{{8}}T[0-9]{{6}}Z\.dump$",
        )
        self.assertTrue(archive.read_bytes().startswith(b"GOOD"))
        self.assertEqual(archive.stat().st_mode & 0o077, 0)
        self.assertIn("restore", self.docker_log.read_text().splitlines())

    def test_rotation_keeps_three_latest_archives_and_unrelated_files(self):
        previous = [self._archive(days) for days in (24, 20, 16, 12, 8, 4)]
        unrelated = self.archives / "manual-export.dump"
        unrelated.write_bytes(b"unrelated synthetic file")
        result = self._run()
        self._assert_success(result)
        files = self._files()
        self.assertIn(unrelated, files)
        self.assertEqual(unrelated.read_bytes(), b"unrelated synthetic file")
        archives = files - {unrelated}
        self.assertEqual(len(archives), 3)
        self.assertTrue(set(previous[-2:]).issubset(archives))
        self.assertTrue(all(not path.exists() for path in previous[:-2]))

    def test_dump_failure_keeps_previous_archives_and_removes_partial_file(self):
        previous = {self._archive(days) for days in (12, 8, 4)}
        result = self._run(FAKE_DUMP_FAIL="1")
        self._assert_failure(result)
        self.assertEqual(self._files(), previous)
        self.assertTrue(all(path.read_bytes().startswith(b"GOOD") for path in previous))

    def test_new_invalid_archive_is_not_published_or_rotated(self):
        previous = {self._archive(days) for days in (12, 8, 4)}
        result = self._run(FAKE_DUMP_INVALID="1")
        self._assert_failure(result)
        self.assertEqual(self._files(), previous)

    def test_existing_invalid_archive_prevents_deletion(self):
        previous = {self._archive(days) for days in (16, 12, 8)}
        invalid = self._archive(4, content=b"BAD previous synthetic archive")
        result = self._run()
        self._assert_failure(result)
        self.assertTrue((previous | {invalid}).issubset(self._files()))

    def test_if_due_skips_recent_success_without_contacting_docker(self):
        recent = self._archive(3)
        result = self._run("--if-due")
        self._assert_success(result)
        self.assertEqual(self._files(), {recent})
        self.assertFalse(self.docker_log.exists())

    def test_if_due_creates_archive_after_four_days(self):
        previous = self._archive(5)
        result = self._run("--if-due")
        self._assert_success(result)
        self.assertEqual(len(self._files()), 2)
        self.assertIn(previous, self._files())
        self.assertIn("dump", self.docker_log.read_text().splitlines())

    def test_if_due_creates_archive_at_exactly_96_hours(self):
        now = datetime(2026, 11, 9, tzinfo=timezone.utc)
        self._freeze_time(now)
        previous = self._archive_at(now - timedelta(hours=96))
        result = self._run("--if-due")
        self._assert_success(result)
        self.assertEqual(len(self._files()), 2)
        self.assertIn(previous, self._files())
        self.assertIn("dump", self.docker_log.read_text().splitlines())

    def test_if_due_skips_one_second_before_96_hours(self):
        now = datetime(2026, 11, 9, tzinfo=timezone.utc)
        self._freeze_time(now)
        previous = self._archive_at(now - timedelta(hours=96) + timedelta(seconds=1))
        result = self._run("--if-due")
        self._assert_success(result)
        self.assertEqual(self._files(), {previous})
        self.assertFalse(self.docker_log.exists())

    def test_if_due_creates_initial_archive(self):
        result = self._run("--if-due")
        self._assert_success(result)
        self.assertEqual(len(self._files()), 1)

    def test_future_archive_is_reported_without_rotation(self):
        future = self._archive(-1)
        result = self._run("--if-due")
        self._assert_failure(result)
        self.assertEqual(self._files(), {future})
        self.assertFalse(self.docker_log.exists())

    def test_timestamp_collision_does_not_overwrite_existing_archive(self):
        now = datetime(2026, 11, 9, tzinfo=timezone.utc)
        self._freeze_time(now)
        previous = self._archive_at(now)
        original = previous.read_bytes()
        result = self._run()
        self._assert_failure(result)
        self.assertTrue(self.dump_finished.exists())
        self.assertEqual(self._files(), {previous})
        self.assertEqual(previous.read_bytes(), original)

    def test_clock_regression_after_dump_preserves_existing_archives(self):
        now = datetime(2026, 11, 9, tzinfo=timezone.utc)
        self._freeze_time(now, completed=now - timedelta(days=5))
        previous = {
            self._archive_at(now - timedelta(days=days))
            for days in (12, 8, 4)
        }
        result = self._run()
        self._assert_failure(result)
        self.assertTrue(self.dump_finished.exists())
        self.assertEqual(self._files(), previous)
        self.assertTrue(all(path.read_bytes().startswith(b"GOOD") for path in previous))

    def test_concurrent_run_preserves_archives(self):
        previous = self._archive(5)
        with self.lock.open("w") as held_lock:
            fcntl.flock(held_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self._run()
        self._assert_failure(result)
        self.assertEqual(self._files(), {previous})
        self.assertFalse(self.docker_log.exists())


if __name__ == "__main__":
    unittest.main()
