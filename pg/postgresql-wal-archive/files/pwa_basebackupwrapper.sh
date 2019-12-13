#!/bin/bash
#
# pg_basebackup wrapper for periodic backup jobs
# Southbridge LLC, 2017-2018 A.D.
#

set -E
set -o nounset

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR="$(mktemp --tmpdir "${bn%\.*}.XXXX")"
readonly CONFIG="${bn%\.*}.conf"
readonly BIN_REQUIRED="pg_basebackup logger mailx"
readonly pgpass="${HOME}/.pgpass"
readonly BAKDIR="$(date '+%FT%H%M')"
# CONSTANTS END

# DEFAULTS BEGIN
typeset RUNUSER="basebackup"
typeset BAKUSER="replicator"
typeset BASEDIR="/srv/basebackup"
typeset MAILXTO="root"
typeset MAIL_SUBJ="ERRORS REPORTED: PostgreSQL Backup error Log"
typeset -i STRIP_LAST_DASH_IN_ADDRESS=0
# DEFAULTS END

typeset -i BACKUP_DEPTH=0 NOMAIL=0 DEBUG=0 DRY_RUN=0

main() {
    local fn=${FUNCNAME[0]}
    local -i warn=0

    trap 'except $LINENO' ERR
    trap _exit EXIT

    if (( ! DEBUG )); then
	exec 4>&2		# Link file descriptor #4 with stderr. Preserve stderr
	exec 2>>"$LOGERR"	# stderr replaced with file $LOGERR
    fi

    checks_main

    for i in "$@"; do
	backup "$i"
    done

    exit 0
}

backup() {
    local fn=${FUNCNAME[0]}
    local instance_address="$1"
    local PG_VERSION="" PG_VER_NUM="" COMMAND="" xlog=""

    _get_version
    COMMAND=/usr/pgsql-${PG_VERSION}/bin/pg_basebackup

    if [[ ! -f "$COMMAND" ]]; then
	echo "Required PostgreSQL version not installed, cannot continue" >&2
	false
    fi

    if ! grep -Fq "$instance_address" "$pgpass"
    then
        echo "PostgreSQL authorization file ($pgpass) is not contains authentication data for '$instance_address' address." >&2
        false
    fi

    if (( STRIP_LAST_DASH_IN_ADDRESS )); then
        local instance_catalog=${instance_address%-*}
    else
        local instance_catalog=${instance_address}
    fi

    if [[ ! -d "${BASEDIR}/$instance_catalog" ]]; then
	if (( DEBUG )); then
	    echo "RUN: mkdir \"${BASEDIR}/$instance_catalog\"" >&2
	fi
	if (( ! DRY_RUN )); then
	    mkdir "${BASEDIR}/$instance_catalog"
	fi
    fi

    _log "making base backup of '$instance_address' PostgreSQL instance (${PG_VERSION})"

    cd "${BASEDIR}/$instance_catalog" || exit 1
    # Удаление всех каталогов в текущем, оставляя только (( BACKUP_DEPTH - 1 ))
    if (( ! DRY_RUN )); then
	find . -maxdepth 1 -mindepth 1 -type d -printf '%P\n' | sort -r | tail -n +$BACKUP_DEPTH | xargs rm -rf --
    fi

    if (( PG_VER_NUM < 100000 )); then
	xlog=xlog
    else
	xlog=wal
    fi

    if (( ! DRY_RUN )); then
	warn=1
	$COMMAND --host="$instance_address" --username="$BAKUSER" --pgdata="$BAKDIR" --no-password --${xlog}-method=stream --status-interval=1
	warn=0
    fi

    if [[ -d "${BASEDIR}/${instance_catalog}/$BAKDIR" ]]; then
        bakdir_size=$(du -sb "${BASEDIR}/${instance_catalog}/$BAKDIR"|awk '{ print $1 }')
        # Если размер полученного каталога с бэкапом составляет менее 2M, то бэкап признаётся неудавшимся и каталог удаляется
        if (( bakdir_size < 2000000 )); then
            rm -rf "${BASEDIR:?}/${instance_catalog}/$BAKDIR"
        fi
    fi

}

_get_version() {
    local fn=${FUNCNAME[0]}

    PG_VERSION=$(psql -AtXc 'SHOW server_version' -U "$BAKUSER" -h "$instance_address" template1|sed -r 's/\.[0-9]+$//')
    PG_VER_NUM=$(psql -AtXc 'SHOW server_version_num;' -U "$BAKUSER" -h "$instance_address" template1)

    if [[ -z "$PG_VERSION" ]]; then
	echo "cannot get PostgreSQL version, exiting" >&2
	false
    fi
}

checks_main() {
    local fn=${FUNCNAME[0]}

    # Проверка наличия нужных бинарников
    for i in $BIN_REQUIRED; do
        if ! hash "$i" 2>/dev/null
        then
            echo "Required binary '$i' is not installed" >&2
            false
        fi
    done

    if [[ $(whoami) != "$RUNUSER" ]]; then
        echo "This script must be run as '$RUNUSER' user" >&2
        false
    fi

    if (( ! BACKUP_DEPTH )); then
        echo "Required parameter '--depth' is missing" >&2
        false
    fi

    if [[ ! -r "$pgpass" ]]; then
        echo "PostgreSQL authorization file ($pgpass) is missing or unreadable" >&2
        false
    fi

}

_log() {
    local fn=${FUNCNAME[0]}
    local arg2="${2:-info}"

    logger -p "user.$arg2" -t "$bn" "${arg2^^}: $1"
}

except() {
    local ret=$?
    local no=${1:-no_line}

    if (( ! NOMAIL )); then
	if ! grep -Fq 'could not receive data from WAL stream: server closed the connection unexpectedly' "$LOGERR"; then
	    echo -e "\\tПроизошла ошибка при выполнении скрипта ${0} (строка ${no}, функция '$fn'), 
выполняющего полное копирование СУБД PostgreSQL посредством команды pg_basebackup с хоста *${instance_address}*.
\\tВывод сбойной команды:\\n\\n  $(awk '$1=$1' ORS=' ' "${LOGERR}")" | mailx -s "$MAIL_SUBJ" $MAILXTO
	fi
    fi

    if [[ -t 1 ]]; then
        echo "* FATAL: error occured in function '$fn' on line ${no}. Output: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'" 1>&2
    fi

    logger -p user.warning -t "$bn" "WARNING: error occured in function '$fn' on line ${no}. Command output: '$(awk '$1=$1' ORS=' ' "${LOGERR:-NOFILE}")'"

    if (( warn )); then
	_log "continuing..."
	return $ret
    else
	_log "exiting..." err
	[[ -f $LOGERR ]] && rm "$LOGERR"
	exit $ret
    fi
}

_exit() {
    local ret=$?
    local -i bakdir_size=0

    if (( ! DEBUG )); then
	exec 2>&4 4>&-	# Restore stderr and close file descriptor #4
    fi

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\\tUsage: $bn [OPTIONS] <postgresql_instance_address1> ...\\n
    Options:

    --basedir, -b <path>	BASEDIR (default: '$BASEDIR')
    --depth, -D <n>		number of stored backups
    --strip-last-dash, -s	strip last dash-separated part of instance address
    --user, -U			user for run this script
    --debug, -d			print some additional info
    --dry-run, -n		do not make action, print info only (with -d)
    --help, -h			print this text
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o b:D:U:sdnh --longoptions basedir:,depth:,strip-last-dash,user:,debug,dry-run,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-b|--basedir)		BASEDIR=$2 ;	shift 2	;;
	-D|--depth)		BACKUP_DEPTH=$2 ;		shift 2	;;
	-U|--user)		RUNUSER=$2 ;	shift 2	;;
	-s|--strip-last-dash)	STRIP_LAST_DASH_IN_ADDRESS=1 ;	shift	;;
	-d|--debug)		DEBUG=1 ;	shift	;;
	-n|--dry-run)		DRY_RUN=1 ;	shift	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

if [[ "${1:-NOP}" == "NOP" ]]; then
    usage
    exit 1
fi

main "$@"

## EOF ##
