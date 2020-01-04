#!/bin/bash
#
# Mysqldump wrapper for using with Bacula.
# Inspired by https://wiki.bacula.org/doku.php?id=application_specific_backups:mysql
#

set -o nounset
set -o errtrace
set -o pipefail

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly BIN_REQUIRED="mysql mysqldump bzip2"
# CONSTANTS END

# DEFAULTS BEGIN
typeset -i KEEPDAYS=2
typeset SPOOL=/var/preserve/mysqldump
typeset -a Nobase=(
    "information_schema"
    "performance_schema"
    )
# DEFAULTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT

    checks

    local -a Dblist=()
    local timestamp="" muser="root" mpass=""

    if [[ -f /root/.passwd.mysql.bacula ]]; then
	muser=bacula
	mpass=$(cat /root/.passwd.mysql.bacula)
    fi

    timestamp=$(date +'%FT%H%M%S')

    mapfile -t Dblist < <(echo 'SHOW DATABASES;' | mysql -u $muser ${mpass:+-p$mpass} -BN)

    mkdir -p "${SPOOL}/$timestamp"

    for (( i = 0; i < ${#Dblist[@]}; i++ )); do
	if inArray Nobase "${Dblist[i]}"; then
	    continue
	else
	    echo_info_n "Backing up ${Dblist[i]}... "
	    mysqldump --routines --single-transaction -u $muser ${mpass:+-p$mpass} \
		"${Dblist[i]}" | bzip2 - > "${SPOOL}/${timestamp}/${Dblist[i]}.sql.bz2"
	    echo "Done."
	fi
    done

    find ${SPOOL} -mindepth 1 -type f -mtime +${KEEPDAYS} -delete
    find ${SPOOL} -mindepth 1 -type d -empty -delete

    exit 0
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
}

except() {
    local ret=$?
    local no=${1:-no_line}

    echo_fatal "error occured in function '$fn' near line ${no}."

    exit $ret
}

_exit() {
    local ret=$?

    exit $ret
}

usage() {
    echo -e "\\n    Usage: $bn [OPTIONS] <parameter>\\n
    Options:

    -k, --keepdays <uint>	keep old backups <uint> days
    -s, --spool-dir /path	backups store
    -h, --help			print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o k:s:h --longoptions keepdays:,spool-dir,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-k|--keepdays)		KEEPDAYS=$2 ;	shift 2	;;
	-s|--spool-dir)		SPOOL=$2 ;	shift 2	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

echo_err()      { echo "* ERROR: $*" ;		}
echo_fatal()    { echo "* FATAL: $*" ;		}
echo_warn()     { echo "* WARNING: $*" ;	}
echo_info()     { echo "* INFO: $*" ;		}
echo_info_n()   { echo -n "* INFO: $*" ;	}
echo_ok()       { echo "* OK" ;			}

main

## EOF ##
