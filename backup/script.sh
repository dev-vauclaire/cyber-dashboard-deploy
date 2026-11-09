#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C

PROJECT_DIR="${PROJECT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
BACKUP_MOUNT="${BACKUP_MOUNT:-/mnt/nfs_Qnap}"
LOCK_FILE="${LOCK_FILE:-/run/cyber-dashboard-backup.lock}"
readonly BACKUP_INTERVAL_SECONDS=345600
readonly BACKUPS_TO_KEEP=3
if_due=false
temporary_archive=''

log() {
    printf '%s\n' "$*" >&2
}

fail() {
    log "Erreur : $*"
    exit 1
}

cleanup() {
    local status=$?
    if [[ -n "$temporary_archive" ]] && ! rm -f -- "$temporary_archive"; then
        log "Impossible de supprimer le fichier temporaire de sauvegarde."
    fi
    return "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

case "${1:-}" in
    '') ;;
    --if-due) if_due=true ;;
    *) fail "Usage : $0 [--if-due]" ;;
esac
(( $# <= 1 )) || fail "Usage : $0 [--if-due]"

for dependency in docker flock mountpoint findmnt realpath date mktemp; do
    command -v "$dependency" >/dev/null || fail "Commande requise absente : $dependency"
done

[[ -f "$PROJECT_DIR/docker-compose.yaml" ]] || fail "Projet Compose introuvable."
PROJECT_DIR="$(realpath -e -- "$PROJECT_DIR")"
[[ -d "$BACKUP_MOUNT" ]] || fail "Point de montage introuvable."
BACKUP_MOUNT="$(realpath -e -- "$BACKUP_MOUNT")"
[[ "$BACKUP_MOUNT" != / ]] || fail "Le point de montage doit être un partage NFS dédié."

require_nfs_mount() {
    mountpoint -q -- "$BACKUP_MOUNT" &&
        findmnt --noheadings --raw --mountpoint "$BACKUP_MOUNT" --types nfs,nfs4 >/dev/null ||
        fail "Le partage NFS n'est pas monté."
}

compose() {
    # Compose doit lire la configuration du projet, même lorsque le script travaille sur le NAS.
    (cd -- "$PROJECT_DIR" && docker compose --project-directory "$PROJECT_DIR" \
        --file "$PROJECT_DIR/docker-compose.yaml" "$@")
}

validate_archive() {
    compose exec -T db pg_restore --list < "$1" >/dev/null 2>&1
}

# Le verrou reste local : flock n'est pas utilisé sur le partage NFS.
exec {lock_fd}>"$LOCK_FILE"
flock --nonblock "$lock_fd" || fail "Une sauvegarde est déjà en cours."
require_nfs_mount

# Le répertoire courant garde une référence au montage et évite un repli vers le disque local.
cd -- "$BACKUP_MOUNT"
require_nfs_mount
[[ ! -L postgresql ]] || fail "Le dossier de sauvegarde ne doit pas être un lien symbolique."
mkdir -p -- postgresql
[[ -r postgresql && -w postgresql && -x postgresql ]] ||
    fail "Le dossier de sauvegarde n'est pas accessible en lecture et en écriture."
cd -- postgresql

shopt -s nullglob
archives=()
for candidate in cyber-dashboard-postgresql_*.dump; do
    if [[ "$candidate" =~ ^cyber-dashboard-postgresql_[0-9]{8}T[0-9]{6}Z\.dump$ ]]; then
        [[ -f "$candidate" && ! -L "$candidate" ]] || fail "Une archive gérée n'est pas un fichier régulier."
        archives+=("$candidate")
    fi
done

# Les noms UTC, triés par le glob en locale C, restent ordonnés après un redémarrage.
if (( ${#archives[@]} > 0 )); then
    latest="${archives[-1]}"
    stamp="${latest#cyber-dashboard-postgresql_}"
    stamp="${stamp%.dump}"
    latest_time="$(date -u --date="${stamp:0:4}-${stamp:4:2}-${stamp:6:2} ${stamp:9:2}:${stamp:11:2}:${stamp:13:2} UTC" +%s)" ||
        fail "L'horodatage de la dernière archive est invalide."
    now="$(date -u +%s)"
    (( latest_time <= now )) || fail "La dernière archive est datée dans le futur ; vérifier l'horloge."
    if "$if_due" && (( now - latest_time < BACKUP_INTERVAL_SECONDS )); then
        log "Sauvegarde non échue : le dernier dump a moins de 96 heures."
        exit 0
    fi
fi

for archive in "${archives[@]}"; do
    validate_archive "$archive" || fail "Une archive existante est illisible ; aucune sauvegarde supprimée."
done

temporary_archive="$(mktemp '.cyber-dashboard-postgresql_XXXXXX.partial')"
if ! compose exec -T db sh -ceu '
    : "${POSTGRES_USER:?Configuration PostgreSQL absente}"
    : "${POSTGRES_DB:?Configuration PostgreSQL absente}"
    exec pg_dump --format=custom --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"
' > "$temporary_archive" 2>/dev/null; then
    fail "Échec de l'export PostgreSQL ; aucune sauvegarde supprimée."
fi

validate_archive "$temporary_archive" || fail "La nouvelle archive est illisible ; aucune sauvegarde supprimée."
require_nfs_mount
completed_time="$(date -u +%s)"
if (( ${#archives[@]} > 0 && completed_time < latest_time )); then
    fail "L'horloge a reculé pendant l'export ; aucune sauvegarde supprimée."
fi
archive_name="cyber-dashboard-postgresql_$(date -u --date="@$completed_time" +%Y%m%dT%H%M%SZ).dump"
[[ ! -e "$archive_name" && ! -L "$archive_name" ]] || fail "Une archive existe déjà pour cette seconde."
mv -T -- "$temporary_archive" "$archive_name"
temporary_archive=''
log "Sauvegarde créée : $archive_name"

# Aucune ancienne archive n'est supprimée avant publication réussie du nouveau dump.
require_nfs_mount
archives+=("$archive_name")
excess=$(( ${#archives[@]} - BACKUPS_TO_KEEP ))
for (( index=0; index<excess; index++ )); do
    rm -- "${archives[index]}"
done
log "Rotation terminée : conservation des trois derniers dumps au maximum."
