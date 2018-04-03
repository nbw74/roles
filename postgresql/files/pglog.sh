#!/bin/bash
#
# Wrapper for pgBadger for usage with rsyslog
# postgresql log collector
#

set -o nounset
set -o errtrace
set -o pipefail

# DEFAULTS BEGIN
typeset SOURCE=""
typeset -i DAY=0 VERBOSE=0 NOSESSION=0
typeset -i MAXLENGTH=4096
typeset LOGDIR="/var/log/pglog"
typeset REPORTS="/opt/reports"
typeset TITLE="$(hostname -d)"
typeset TRUNCATE="" NOUSER=""
# DEFAULTS END

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly BIN_REQUIRED="pgbadger bc"
# CONSTANTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT

    touch "$LOGERR"
    exec 4>&2		# Link file descriptor #4 with stderr. Preserve stderr
    exec 2>>"$LOGERR"	# stderr replaced with file $LOGERR

    checks

    local starttime="" endtime="" delta=""
    local -a Sources
    local -a Trhosts=()
    local -a Nousers=()

    if [[ -n $SOURCE ]]; then
	Sources[0]=$SOURCE
    else
	mapfile -t Sources < <( find "$LOGDIR" -maxdepth 1 -type d ! -wholename "$LOGDIR" -printf '%P\n' )
    fi

    # Host with truncate queries
    # shellcheck disable=SC2034
    read -ra Trhosts < <( echo "$TRUNCATE" | awk 'BEGIN { FS=","; OFS=" " } { $1=$1; print $0 }' )
    # Disable reports for this users
    # shellcheck disable=SC2034
    read -ra Nousers < <( echo "$NOUSER" | awk 'BEGIN { FS=","; OFS=" " } { $1=$1; print $0 }' )

    starttime="$(date '+%s.%3N')"
    for i in "${!Sources[@]}"; do
	_pgbadger "${Sources[i]}"
    done
    endtime="$(date '+%s.%3N')"
    delta="$(echo "${endtime}-$starttime" | bc -l || :)"

    logger -p user.info -t "$bn" "* INFO: ${#Sources[@]} logs parsed in ${delta:-N} s. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"

    exit 0
}

_pgbadger() {
    local fn=${FUNCNAME[0]}
    local -i n=0
    local date="" timezone="" v="--quiet" s="" m="" u=""

    timezone="$(date '+%:::z' || :)"

    if [[ ${1:-NOP} == "NOP" ]]; then
	false
    else
	local outdir="${REPORTS}/$1"
	local logdir="${LOGDIR}/$1"
    fi

    if [[ ! -d "$outdir" ]]; then
	mkdir "$outdir"
    fi
    # Get CPUs count
    n=$(grep -c '^processor' /proc/cpuinfo)
    # Get log date
    if (( DAY == 1 )); then
	date=$(date '+%F')
    elif (( DAY == 2 )); then
	date=$(date --date='yesterday' '+%F')
    else
	false
    fi
    # Verbosity (NOT WORKING)
    if (( VERBOSE == 1 )); then
	v=""
    elif (( VERBOSE > 1 )); then
	v="--verbose"
    fi
    # Disable connection stats
    if (( NOSESSION ));  then
	s="--disable-connection --disable-session"
    fi

    for (( i = 0; i < ${#Nousers[@]}; i++ )); do
	u="$u --exclude-user ${Nousers[i]}"
    done

    if (( ${#Trhosts[@]} > 0 )); then
	# If source queries should be truncated
	if [[ ${Trhosts[0]} == "all" ]]; then
	    m="--maxlength $MAXLENGTH"
	elif inArray Trhosts "$1"; then
	    m="--maxlength $MAXLENGTH"
	fi
    fi
    # shellcheck disable=SC2086
    pgbadger --incremental --format syslog --jobs "$n" --average 1 \
	--retention 12 --extra-files --outdir "$outdir" $m $s $v $u \
	--start-monday --title "$TITLE" --timezone "${timezone:-+03}" \
	"${logdir}/postgresql-${date}.log"

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

    if (( ! DAY )); then
	echo "Probably you want pass the '--today' parameter?" >&2
	false
    fi
}

inArray() {
    local array="$1[@]"
    local seeking=$2
    local -i in=1

    for e in ${!array}; do
        if [[ $e == "$seeking" ]]; then
            in=0
            break
        fi
    done

    return $in
}

except() {
    local ret=$?
    local no=${1:-no_line}

    if [[ -t 1 ]]; then
        echo "* FATAL: error occured in function '$fn' on line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    fi

    logger -p user.err -t "$bn" "* FATAL: error occured in function '$fn' on line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    exit $ret
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

    -c, --company <string>		web-page title string (default: domain)
    -H, --source-host <nodename>	optional: set log nodename (default: all logs)
    -l, --logdir <path>			pg logs directory (default: /var/log/pglog)
    --maxlength int			queries will be truncated to the given size (default: 4096)
    --nosession				do not generate session and connection reports
    -r, --reports <path>		reports directory (default: /opt/reports)
    -t, --today				process today log
    --truncate <node1[,node2...]|all>	truncate displayed query length for this nodes to --maxlength
    -U, --nouser <username>		exclude entries for the specified user from report
    -v, --verbose			pgbadger verbose output (use twice for debug). Not working.
    -y, --yesterday			process yesterday log (mainly for daily cron job)
    -h, --help				print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o c:H:l:r:tU:yvh --longoptions company:,source-host:,logdir:,\
maxlength:,nosession,reports:,today,truncate:,nouser:,yesterday,verbose,\
help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-c|--company)		TITLE=$2 ;	shift 2	;;
	-H|--source-host)	SOURCE=$2 ;	shift 2	;;
	-l|--logdir)		LOGDIR=$2 ;	shift 2	;;
	--maxlength)		MAXLENGTH=$2 ;	shift 2	;;
	--nosession)		NOSESSION=1 ;	shift	;;
	-r|--reports)		REPORTS=$2 ;	shift 2	;;
	-t|--today)		DAY=1 ;		shift	;;
	--truncate)		TRUNCATE=$2 ;	shift 2	;;
	-U|--nouser)		NOUSER=$2 ;	shift 2	;;
	-v|--verbose)		((VERBOSE++)) ;	shift	;;
	-y|--yesterday)		DAY=2 ;		shift	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

main

## EOF ##
