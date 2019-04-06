#!/bin/bash
# THIS FILE IS MANAGED BY ANSIBLE, ALL CHANGES WILL BE LOST
#
# Lock file remover for pacemaker pgsql resource-agent
# by nbw for Southbridge LLC, 2018 A.D.
#

set -o nounset
set -o errtrace
set -o pipefail

# DEFAULTS BEGIN
typeset STATUS_PATH="/var/spool/crm_mon/status.html"
typeset -i WAIT_BEFORE_RM=15
typeset MAILXTO="root"
typeset MAIL_SUBJ="ERRORS REPORTED: PostgreSQL cluster warning"
typeset PG_VERSION=""
# DEFAULTS END

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly BIN_REQUIRED="mailx html2text"
# CONSTANTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT

    exec 4>&2		# Link file descriptor #4 with stderr. Preserve stderr
    exec 2>>"$LOGERR"	# stderr replaced with file $LOGERR

    checks

    local LOCKFILE="/var/lib/pgsql/${PG_VERSION}/tmp/PGSQL.lock"

    if ! get_status; then
	sleep $WAIT_BEFORE_RM

	if ! get_status; then
	    if [[ -f "$LOCKFILE" ]]; then
		rm "$LOCKFILE"
		_logger "PGSQL-status is 'STOP', lock file removed"
	    fi
	fi
    fi

    exit 0
}

get_status() {
    local fn=${FUNCNAME[0]}
    local status=""

    status="$(html2text "$STATUS_PATH" | grep -A8 "### Node: $(uname -n)" | awk '/PGSQL-status:/ { print $3; exit }')"

    if [[ $status == "STOP" ]]; then
	return 1
    else
	return 0
    fi
}

checks() {
    local fn=${FUNCNAME[0]}
    # Required binaries check
    for i in $BIN_REQUIRED; do
        if ! command -v "$i" >/dev/null
        then
            echo "Required binary '$i' is not installed" >&2
            false
        fi
    done

    if [[ -z $PG_VERSION ]]; then
	echo "Required parameter is missing" >&2
	false
    fi
}

except() {
    local ret=$?
    local no=${1:-no_line}

    if [[ -t 1 ]]; then
        echo "* FATAL: error occured in function '$fn' near line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    fi

    echo "${bn}: Runtime error. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'" | mailx -s "$MAIL_SUBJ" $MAILXTO

    logger -p user.err -t "$bn" "* FATAL: error occured in function '$fn' near line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    exit $ret
}

_logger() {
    local fn=${FUNCNAME[0]}

    logger -p user.info -t "$bn" "* INFO: $*"
    echo "$bn" "* INFO: $*" | mailx -s "$MAIL_SUBJ" $MAILXTO
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

    -s, --status-path <filepath>	path to crm_mon status file (default: ${STATUS_PATH})
    -w, --wait-before-rm <n>		wait n sec before second check and removing (default: ${WAIT_BEFORE_RM})
    -V, --pg-version <N[.N]>		PostgreSQL version (mandatory)
    -h, --help				print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o s:w:h:V: --longoptions status-path:,wait-before-rm:,help,pg-version: -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-s|--status-path)	STATUS_PATH=$2 ;	shift 2	;;
	-w|--wait-before-rm)	WAIT_BEFORE_RM=$2 ;	shift 2	;;
	-V|pg-version)		PG_VERSION=$2 ;		shift 2	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

main

## EOF ##
