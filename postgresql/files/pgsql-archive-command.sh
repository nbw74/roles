#!/bin/bash
# THIS FILE IS ANSIBLE MANAGED
#
# Script for use with archive_command
# for PostgreSQL 9.5+.
# Southbridge LLC, 2017-2018 A.D.
#

set -o nounset
set -o pipefail

# DEFAULTS BEGIN
typeset FULLNAME="" BASENAME="" PG_VERSION="" BACKUPSERVER="" BACKUPDIR=""
typeset BACKUPUSER="walbackup"
BACKUPDIR="$(hostname -s)"
# DEFAULTS END

# CONSTANTS BEGIN
readonly bn=$(basename "$0")
readonly BIN_REQUIRED="lbzip2 rsync logger"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly rsync_opts="-ab --backup-dir=../${BACKUPDIR}-dupbak --suffix=.$(hostname -s).$(shuf -i 1000-9999 -n 1)"
# CONSTANTS END

main() {
    local fn=${FUNCNAME[0]}
    local -i warn=0

    trap 'except $LINENO' ERR
    trap _exit EXIT

    touch "$LOGERR"
    exec 4>&2
    exec 2>>"$LOGERR"

    checks

    local PGARCHIVE="/var/lib/pgsql/${PG_VERSION}/pg_archive"

    if [[ ! -d "$PGARCHIVE" ]]; then
	mkdir "$PGARCHIVE"
    fi
    # if WAL archive file already exists - create backup for it
    backup "${PGARCHIVE}/${BASENAME}"
    # Copy WAL file into pg_archive directory
    cp "$FULLNAME" "${PGARCHIVE}/$BASENAME"
    # if compressed file already exists - create backup for it
    backup "${PGARCHIVE}/${BASENAME}.bz2"
    # Compress WAL archive file with lbzip2
    lbzip2 "${PGARCHIVE}/$BASENAME"

    warn=1
    # Copy compressed file to remote server
    # shellcheck disable=SC2086
    if rsync $rsync_opts "${PGARCHIVE}/${BASENAME}.bz2" ${BACKUPUSER}@${BACKUPSERVER}:${BACKUPDIR}/ >/dev/null
    then
        rm "${PGARCHIVE}/${BASENAME}.bz2"
    fi

    exit 0
}

backup() {
    local fn=${FUNCNAME[0]}
    local arg1="${1:?}"

    if [[ -f "$arg1" ]]; then
        mv "$arg1" "${arg1}-$(shuf -i 1000-9999 -n 1)"
    fi
}

checks() {
    local fn=${FUNCNAME[0]}

    for i in $BIN_REQUIRED; do
        if ! hash "$i"
        then
            false
        fi
    done

    if [[ -z "$FULLNAME" || -z "$BASENAME" || -z "$BACKUPSERVER" || -z "$PG_VERSION" ]]; then
        echo "Required option is missing" >"$LOGERR"
        false
    fi
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

_exit() {
    local ret=$?

    exec 2>&4 4>&-

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\\n    Usage: $bn OPTIONS\\n
    Options:

    -p, --fullname <path>	path name of the file to archive (REQUIRED)
    -f, --basename <file>	only the file name (REQUIRED)
    -H, --server <addr>		archive server address (REQUIRED)
    -U, --user <name>		user on server (default is 'walbackup')
    -D, --dir <name>		dir for WALs on server (default is '$(hostname -s)')
    -V, --pg-version <ver>	PostgreSQL major version (9.4, 10 ... - REQUIRED)
    -h, --help			print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o p:f:H:U:D:V:h --longoptions fullname:,basename:,server:,user:,dir:,pg-version:,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-p|--fullname)		FULLNAME=$2 ;		shift 2	;;
	-f|--basename)		BASENAME=$2 ;		shift 2	;;
	-H|--server)		BACKUPSERVER=$2 ;	shift 2	;;
	-U|--user)		BACKUPUSER=$2 ;		shift 2	;;
	-D|--dir)		BACKUPDIR=$2 ;		shift 2	;;
	-V|--pg-version)	PG_VERSION=$2 ;		shift 2	;;
	-h|--help)		usage ;			exit 0	;;
	--)			shift ;			break	;;
	*)			usage ;			exit 1
    esac
done

main
