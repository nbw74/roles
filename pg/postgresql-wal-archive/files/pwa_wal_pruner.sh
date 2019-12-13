#!/bin/bash
#
# Pruning old PostgreSQL WAL archive files
# Southbridge LLC, 2017-2018 A.D.
#

set -E
set -o nounset

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR="$(mktemp --tmpdir "${bn%\.*}.XXXX")"
readonly CONFIG="${bn%\.*}.conf"
readonly BIN_REQUIRED="logger mailx"
# CONSTANTS END

# DEFAULTS BEGIN
typeset RUNUSER="walarchive"
typeset WALDIR="/srv/walarchive"
typeset MAILXTO="root"
typeset MAIL_SUBJ="ERRORS REPORTED: PostgreSQL Backup error Log"
typeset -i RM_COUNT=100
typeset -i MAX_USED_PERC=86
typeset -i MIN_WAL_AGE_DAYS=32
# DEFAULTS END

typeset FILESYSTEM=""
typeset -i NOMAIL=0 warn=0

main() {
    local fn=${FUNCNAME[0]}
    local -i used=0 loop=0 pruned=0

    trap 'except $LINENO' ERR
    trap _exit EXIT

    touch "$LOGERR"
    exec 4>&2		# Link file descriptor #4 with stderr. Preserve stderr
    exec 2>>"$LOGERR"	# stderr replaced with file $LOGERR

    checks
    # Поиск ФС, на которой расположена WALDIR
    find_filesystem
    # Проверяется занятое место, если оно больше MAX_USED_PERC - удаляется RM_COUNT
    # самых старых сегментов WAL
    while true; do

        if (( loop > 10000 )); then
            echo "Infinite loop apparently occured: cannot clear disk space" >&2
            false
        fi

        used=$(df -P | awk -v fs="^$FILESYSTEM" '$0 ~ fs { sub(/%/, ""); print $5 }')

        if (( ! used )); then
            echo "Cannot determine used space for '$WALDIR'" >&2
            false
        fi

        if (( used > MAX_USED_PERC )); then
            pruned=1
            find $WALDIR -type f -regextype sed -regex '.*/[0-9A-F]\{24\}.*' -printf '%T@ %p\n' | sort -n | head -n $RM_COUNT | awk '{ wal=$2; system( "rm -- " wal ) }'
        else
            break
        fi

        loop=$(( loop + 1 ))
    done
    # Если проведена очистка, то проверяется возраст самого старого сегмента
    # из оставшихся и, если он превышает MIN_WAL_AGE_DAYS, то выдаётся алерт
    if (( pruned )); then
        local -i oldest_segment_time_unix=0 min_segment_time_unix=0

        oldest_segment_time_unix="$(find $WALDIR -type f -regextype sed -regex '.*/[0-9A-F]\{24\}.*' -printf '%T@\n' | sort -n | head -n 1 | awk -F'.' '{ print $1 }')"
        min_segment_time_unix=$(date "+%s" -d "$MIN_WAL_AGE_DAYS days ago")

        if (( ! oldest_segment_time_unix || ! min_segment_time_unix )); then
            echo "Time cannot be 0. Check script commands" >&2
            false
        fi

        if (( oldest_segment_time_unix > min_segment_time_unix )); then
            warn=1
	    echo "Oldest segment age ($(( ( $(date +%s) - oldest_segment_time_unix ) / 86400 )) days) less than $MIN_WAL_AGE_DAYS days!" >&2
            false
            warn=0
        fi
    fi

    exit 0
}

find_filesystem() {
    local fn=${FUNCNAME[0]}
    local check_path=$WALDIR
    local -i loop=0

    while true; do

        if (( loop > 10 )); then
            echo "Infinite loop apparently occured: cannot find FILESYSTEM" >&2
            false
        fi

        FILESYSTEM=$(df -P | awk -v path="$check_path" '$6 == path { print $1 }')

        if [[ -z "$FILESYSTEM" ]]; then
            check_path=${check_path%\/*}
            [[ -z "$check_path" ]] && check_path="/"
        else
            break
        fi

        loop=$(( loop + 1 ))
    done
}

checks() {
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

}

except() {
    local -i ret=$?
    local -i no=${1:-666}

    if (( warn )); then
        MSG='WARNING!'
    else
        MSG='FATAL:'
    fi

    if (( ! NOMAIL )); then
        echo -e "\\tПроизошла ошибка при выполнении скрипта ${0} (строка ${no}, функция '$fn'), 
выполняющего удаление старых WAL с сервера архивов.
\\tВывод сбойной команды:\\n\\n  $(awk '$1=$1' ORS=' ' "${LOGERR:-/dev/null}")" | mailx -s "$MAIL_SUBJ" $MAILXTO
    fi

    if [[ -t 1 ]]; then
        echo "* ${MSG} error occured in function '$fn' on line ${no}. Output: '$(awk '$1=$1' ORS=' ' "${LOGERR:-/dev/null}")'"
    fi

    logger -p user.err -t "$bn" "* ${MSG} error occured in function '$fn' on line ${no}. Output: '$(awk '$1=$1' ORS=' ' "${LOGERR:-/dev/null}")'"

    if (( ! warn )); then
        exit $ret
    fi
}

_exit() {
    local ret=$?

    exec 2>&4 4>&-	# Restore stderr and close file descriptor #4

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\\n    Usage: $bn [OPTIONS]\\n
    Options:

    -m, --min-age <days>	alert if oldest WAL archive age less than <days> | d(32)
    -r, --rm-count <int>	number of WAL archives for one pass remove | d(100)
    -u, --max-used <perc>	start remove oldest WALs if disk usage more than <perc>% | d(86)
    -U, --user			user for run this script
    -b, --waldir <path>		WALDIR (default: '$WALDIR')
    -h, --help			print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o m:r:u:U:b:h --longoptions min-age:,rm-count:,max-used:,user:,waldir:,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-m|--min-age)		MIN_WAL_AGE_DAYS=$2 ;	shift 2	;;
	-r|--rm-count)		RM_COUNT=$2 ;		shift 2	;;
	-u|--max-used)		MAX_USED_PERC=$2 ;	shift 2	;;
	-U|--user)		RUNUSER=$2 ;		shift 2	;;
	-b|--waldir)		WALDIR=$2 ;		shift 2	;;
	-h|--help)		usage ;			exit 0	;;
	--)			shift ;			break	;;
	*)			usage ;			exit 1
    esac
done

main

## EOF ##
