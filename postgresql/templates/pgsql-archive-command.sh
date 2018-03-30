#!/bin/bash
# THIS FILE IS ANSIBLE MANAGED
#
# Script for use with archive_command
# for PostgreSQL 9.5+.
# Southbridge LLC, 2017 A.D.
#

set -o nounset

# CONSTANTS DEFINITIONS BEGIN
readonly bn=$(basename "$0")
readonly hn=$(hostname -s)
readonly FULLNAME="${1:-nop}"
readonly BASENAME="${2:-nop}"
readonly PGARCHIVE="/var/lib/pgsql/{{ postgresql_version_raw }}/pg_archive"
readonly BACKUPUSER="{{ postgresql_wal_backup_user }}"
readonly BACKUPSERVER="{{ postgresql_wal_backup_server }}"
readonly BACKUPDIR="{{ postgresql_wal_backup_dir }}"
readonly BIN_REQUIRED="lbzip2 rsync logger"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly rsync_opts="-ab --backup-dir=../${BACKUPDIR}-dupbak --suffix=.${hn}.$(shuf -i 1000-9999 -n 1)"
# CONSTANTS DEFINITIONS END

main() {
    local fn=${FUNCNAME[0]}
    local -i warn=0

    trap 'except $LINENO' ERR

    for i in $BIN_REQUIRED; do
        if ! hash "$i" 2>"$LOGERR"
        then
            false
        fi
    done

    if [[ "$FULLNAME" == nop || "$BASENAME" == nop ]]; then
        echo "Required option is missing" >"$LOGERR"
        false
    fi

    # Copy WAL file into pg_archive directory
    cp "$FULLNAME" "${PGARCHIVE}/$BASENAME" 2>"$LOGERR"

    # if archive file already exists - move it into backup
    if [[ -f "${PGARCHIVE}/${BASENAME}.bz2" ]]; then
        mv "${PGARCHIVE}/${BASENAME}.bz2" "${PGARCHIVE}/${BASENAME}.bz2-$(shuf -i 1000-9999 -n 1)"
    fi
    # Compress WAL archive file with lbzip2
    lbzip2 "${PGARCHIVE}/$BASENAME" 2>"$LOGERR"

    warn=1
    # Copy compressed file to remote server
    # shellcheck disable=SC2086
    if rsync $rsync_opts "${PGARCHIVE}/${BASENAME}.bz2" ${BACKUPUSER}@${BACKUPSERVER}:${BACKUPDIR}/ 2>"$LOGERR"
    then
        rm "${PGARCHIVE}/${BASENAME}.bz2" 2>"$LOGERR"
    fi

    [[ -f $LOGERR ]] && rm "$LOGERR"

    exit 0
}

except() {
    local ret=$?
    local no=${1:-no_line}

    logger -p user.warning -t "$bn" "* ERROR occured in function '$fn' on line ${no}. Command output: '$(awk '$1=$1' ORS=' ' "${LOGERR:-NOFILE}")'"

    if (( warn )); then
        logger -p user.warning -t "$bn" "* WARNING: continuing..."
        return $ret
    else
        logger -p user.err -t "$bn" "* FATAL: exiting..."
        [[ -f $LOGERR ]] && rm "$LOGERR"
        exit $ret
    fi
}

main
