#!/bin/bash
#
# Show PostgreSQL locking activity
# https://wiki.postgresql.org/wiki/Lock_Monitoring
# Southbridge LLC, 2019 A.D.
#

set -o nounset
set -o errtrace
set -o pipefail

# DEFAULTS BEGIN
typeset -i LINES=100
typeset -i STDOUT=0
# DEFAULTS END

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly LOGOUT=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly LOGCUT=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly BIN_REQUIRED="sudo psql"
# CONSTANTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT

    checks

    local xpaste="" command_sudo="false"
    local -i NO_RM_OUT=0

    if [[ $(whoami) == 'postgres' ]]; then
	command_sudo="psql"
    elif [[ $(whoami) == 'zabbix' ]]; then
	command_sudo="sudo /usr/bin/psql -U postgres"
    else
	command_sudo="sudo -iu postgres psql"
    fi
# shellcheck disable=SC2024
    $command_sudo <<'EOF' > "$LOGOUT"
  SELECT blocked_locks.pid     AS blocked_pid,
         blocked_activity.usename  AS blocked_user,
         blocking_locks.pid     AS blocking_pid,
         blocking_activity.usename AS blocking_user,
         blocked_activity.query    AS blocked_statement,
         blocking_activity.query   AS current_statement_in_blocking_process
   FROM  pg_catalog.pg_locks         blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity  ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks         blocking_locks
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid
    JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
   WHERE NOT blocked_locks.GRANTED;
EOF

    if ! grep -qF '(0 rows)' "$LOGOUT"; then
	if (( STDOUT )); then
	    cat "$LOGOUT"
	else
	    NO_RM_OUT=1
	    head -n $LINES "$LOGOUT" > "$LOGCUT"
	    echo "[...]" >> "$LOGCUT"
	    tail -n 2 "$LOGOUT" >> "$LOGCUT"
	    xpaste=$(curl -H "Content-Type: text/plain" --data-binary "@$LOGCUT" "https://xpaste.pro/paste-file?language=sql&ttl_days=7")
	    echo_info "$xpaste"
	    echo_info "$LOGOUT"
	fi
    else
	if (( ! STDOUT )); then
	    echo_info "No locks found."
	fi
    fi

    exit 0
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

    if [[ -t 1 ]]; then
        echo_fatal "Error occured in function '$fn' near line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    fi

    logger -p user.err -t "$bn" "* FATAL: error occured in function '$fn' near line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    exit $ret
}

usage() {
    echo -e "\\n    Usage: $bn [OPTIONS]\\n
    Options:

    -c, --stdout	    print locks to stdout
    -h, --help		    print help
"
}

_exit() {
    local ret=$?

    [[ -f $LOGERR ]] && rm "$LOGERR"
    [[ -f $LOGCUT ]] && rm "$LOGCUT"

    if [[ $NO_RM_OUT == 0 && -f $LOGOUT ]]; then
	rm "$LOGOUT"
    fi

    exit $ret
}

if [[ $TERM =~ xterm|screen ]]; then
    echo_err()		{ tput setaf 7; echo "* ERROR: $*" ; tput sgr0;		}
    echo_fatal()	{ tput setaf 1; echo "* FATAL: $*" ; tput sgr0;		}
    echo_warn()		{ tput setaf 3; echo "* WARNING: $*" ; tput sgr0;	}
    echo_info()		{ tput setaf 6; echo "* INFO: $*" ; tput sgr0;		}
    echo_ok()		{ tput setaf 2; echo "* OK" ; tput sgr0;		}
else
    echo_err()		{ echo "* ERROR: $*" ;	}
    echo_fatal()	{ echo "* FATAL: $*" ;	}
    echo_warn()		{ echo "* WARNING: $*";	}
    echo_info()		{ echo "* INFO: $*" ;	}
    echo_ok()		{ echo "* OK" ;		}
fi

# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o ch --longoptions stdout,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-c|--stdout)		STDOUT=1 ;	shift	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done
main

## EOF ##
