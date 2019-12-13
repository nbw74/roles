#!/bin/bash
#
# Wrapper for systemd-nspawn containers management
# Southbridge LLC, 2018 A.D.
#

set -o nounset
set -o errtrace
set -o pipefail

# DEFAULTS BEGIN
typeset -i LINES=5
typeset -i RUNTIME=0
# DEFAULTS END

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly BIN_REQUIRED="machinectl"
# CONSTANTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT

#     exec 4>&2		# Link file descriptor #4 with stderr. Preserve stderr
#     exec 2>>"$LOGERR"	# stderr replaced with file $LOGERR

    local arg1="$1"
    local arg2="${2:-NOP}"

    checks

    local target=""
    local -a containersAll=()
    local -a containersRunning=()

    mapfile -t containersAll < <( machinectl --no-legend list-images | awk '{ print $1 }' )
    # shellcheck disable=SC2034
    mapfile -t containersRunning < <( machinectl --no-legend list | awk '{ print $1 }' )

    case $arg1 in
	enter|ente|ent|en|login|logi|log|lo)
	    _m_login
	    ;;
	exec|exe|ex)
	    shift 2
	    _s_exec "$@"
	    ;;
	list|lis|li|l|ls)
	    _m_list
	    ;;
	pid|pi|p)
	    _s_pid
	    ;;
	remove)
	    _m_remove
	    ;;
	shell|shel|she|sh)
	    _s_shell
	    ;;
	start|star)
	    _m_start
	    ;;
	status|statu|stat)
	    _ms_status
	    ;;
	stop|sto)
	    _m_stop
	    ;;
        set|se|s)
            shift 2
            _s_set "$@"
            ;;
	top|to|t)
	    _f_top
	    ;;
	*)
	    echo_err "Unknown parameter."
	    usage
    esac

    exit 0
}

_m_login() {
    local fn=${FUNCNAME[0]}

    __get_target
    __is_not_running error
    machinectl login "$target"
}

_s_shell() {
    local fn=${FUNCNAME[0]}

    __get_target
    __is_not_running error
    systemd-run -t -M "$target" --setenv SUDO_USER="$SUDO_USER" --setenv LANG=en_US.UTF-8 --setenv USER=root --setenv HOME=/root /bin/bash
}

_s_exec() {
    local fn=${FUNCNAME[0]}

    __get_target
    __is_not_running error
    systemd-run -M "$target" "$@"
    __print_journal inside
}

_m_list() {
    local fn=${FUNCNAME[0]}

    if [[ "${containersAll[*]:-NOP}" == "NOP" ]]; then
	echo_info "No containers found."
	return
    fi

    awk 'BEGIN { printf "%-32s", "NAME"; printf "%-10s", "STATE"; printf "%-32s\n", "IP ADDRESS"; }'

    for (( i = 0; i < ${#containersRunning[@]}; i++ )); do
	awk 'BEGIN { printf "%-32s", "'"${containersRunning[i]}"'"; printf "%-10s", "running"; }'
	machinectl status "${containersRunning[i]}" | \
	    awk 'BEGIN { ORS="; " } /Address:/ { sub(/^.*Address: /, ""); flag=1; } /OS:/ { flag=0; } flag { sub(/[[:space:]]*/, ""); print; } END { printf("\n"); }'
    done

    typeset -a containersDead=()

    if [[ "${containersRunning[*]:-NOP}" == "NOP" ]]; then
	containersDead=("${containersAll[@]}")
    else
	for (( i = 0; i < ${#containersAll[@]}; i++ )); do
	    if ! __in_array containersRunning "${containersAll[i]}"; then
		containersDead+=("${containersAll[i]}")
	    fi
	done
    fi

    for (( i = 0; i < ${#containersDead[@]}; i++ )); do
	awk 'BEGIN { printf "%-32s", "'"${containersDead[i]}"'"; printf "%-10s\n", "dead"; }'
    done
}

_m_remove() {
    local fn=${FUNCNAME[0]}
    local yn=""

    __get_target
    __is_running error

    while true; do
	read -r -p "Do you really want to remove container '${target}'? Type uppercase YES (or no) " yn

	case $yn in
	    YES)
                systemctl disable "systemd-nspawn@${target}.service" # dont try to run at host bootup
                if mountpoint -q "/var/lib/machines/$target" ; then
                    rm -rf "/var/lib/machines/$target" 2>/dev/null ||:
                    umount "/var/lib/machines/$target"
                    rmdir "/var/lib/machines/$target"
                else
                    rm -rf "/var/lib/machines/$target"
                fi
		echo_ok
		return
		;;
	    [Nn]*)
		echo_info "Cancelled by user"
		return
		;;
	    *)
		echo_warn "Please answer yes or no"
	esac
    done

}

_s_pid() {
    local fn=${FUNCNAME[0]}

    checks arg

    systemctl status "$arg2" | grep "CGroup:"
}

_m_start() {
    local fn=${FUNCNAME[0]}

    __get_target
    __is_running
    machinectl start "$target"
    echo_ok
    __print_journal
}

_ms_status() {
    local fn=${FUNCNAME[0]}

    __get_target

    ___running() {
	tput bold
	tput setaf 2
	echo "▲ [ ${target} is running ]"
	tput sgr0
	machinectl status "$target"
    }

    ___dead() {
	tput bold
	tput setaf 1
	echo "▼ [ ${target} is dead ]"
	tput sgr0
	systemctl status "systemd-nspawn@${target}.service" || :
    }

    if [[ "${containersRunning[*]:-NOP}" == "NOP" ]]; then
	___dead
    else
	if __in_array containersRunning "$target"; then
	    ___running
	else
	    ___dead
	fi
    fi
}

_m_stop() {
    local fn=${FUNCNAME[0]}

    __get_target
    __is_not_running
    machinectl poweroff "$target"
    echo_ok
    __print_journal
}

_f_top() {
    local fn=${FUNCNAME[0]}

    echo_info "Please use systemd-cgtop (man 1 systemd-cgtop)"
}

_s_set() {
    local fn=${FUNCNAME[0]}

    __get_target
    local args=""
    if (( RUNTIME )); then
        args="--runtime"
    fi
    systemctl $args set-property "systemd-nspawn@${target}.service" "$@"
}

__get_target() {
    local fn=${FUNCNAME[0]}

    checks arg

    if echo "$arg2"|grep -Pq '\..+\.'; then
	target="$arg2"

	if ! __in_array containersAll "$target"; then
	    echo_err "No such container."
	    false
	fi
    else
	local -i matches_count=0

	matches_count=$(printf '%s\n' "${containersAll[@]}" | grep -Fc "$arg2" || :)

	if (( ! matches_count )); then
	    echo_err "No matching container."
	    false
	elif (( matches_count > 1 )); then
	    echo_err "Ambiguity detected, please enter a more complete pattern."
	    false
	fi

	target=$(printf '%s\n' "${containersAll[@]}" | grep "$arg2")
    fi

}

__is_running() {
    local fn=${FUNCNAME[0]}
    local my_arg="${1:-NOP}"

    if [[ "${containersRunning[*]:-NOP}" == "NOP" ]]; then
	return
    fi

    if __in_array containersRunning "$target"; then
	if [[ "$my_arg" == "error" ]]; then
	    echo_err "Container $target is running."
	    false
	else
	    echo_info "Container $target is already running."
	    exit 0
	fi
    fi
}

__is_not_running() {
    local fn=${FUNCNAME[0]}
    local my_arg="${1:-NOP}"

    ___is_not_running_ret() {
	if [[ "$my_arg" == "error" ]]; then
	    echo_err "Container $target is not running."
	    false
	else
	    echo_info "Container $target is not running."
	    exit 0
	fi
    }

    if [[ "${containersRunning[*]:-NOP}" == "NOP"  ]]; then
	___is_not_running_ret
    fi

    if ! __in_array containersRunning "$target"; then
	___is_not_running_ret
    fi

}

__print_journal() {
    local fn=${FUNCNAME[0]}

    sleep 1.5

    if [[ "${1:-NOP}" == "inside" ]]; then
	journalctl --no-pager -n $LINES -M "$target"
    else
	journalctl --no-pager -n $LINES -u "systemd-nspawn@${target}.service"
    fi
}

__in_array() {
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

    if [[ ${1:-NOP} == "arg" ]]; then
	if [[ ${arg2:-NOP} == "NOP" ]]; then
	    echo_err "Required parameter is missing"
	    false
	fi
	return
    fi
    # Required binaries check
    for i in $BIN_REQUIRED; do
	if ! command -v "$i" >/dev/null
	then
	    echo "Required binary '$i' is not installed." >&2
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

_exit() {
    local ret=$?

#     exec 2>&4 4>&-	# Restore stderr and close file descriptor #4

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\\n    Usage: $bn [OPTIONS] <command> <container>

  Options:

    -n, --lines=	When used with start, stop, exec, controls the number of journal lines to show,
			counting from the most recent ones. Takes a positive integer argument. Defaults to 5.
    -r, --runtime       Make changes only temporarily, so that they are lost on the next reboot.
    -h, --help          Print help

  Commands:

    enter		machinectl login <container>
    exec		systemd-run -M <container> <args>
    list		(list containers with status and IP addresses printing)
    login		machinectl login <container>
    pid			systemctl status <pid> | grep CGroup
    remove		rm -rf /var/lib/machines/<container> (and unmount LV)
    shell		systemd-run -t -M <container> bash
    start		machinectl start <container>
    status		machinectl status (if running) or systemctl status (if dead)
    stop		machinectl poweroff <container>
    top			(please use systemd-cgtop)
    set			systemctl set-property <container> <args>
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o n:hr --longoptions lines:,help,runtime -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-n|--lines)		LINES=$2 ;	shift 2	;;
        -r|--runtime)           RUNTIME=1;      shift   ;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

echo_err()	{ tput setaf 7; echo "* ERROR: $*" ; tput sgr0;		}
echo_fatal()	{ tput setaf 1; echo "* FATAL: $*" ; tput sgr0;		}
echo_warn()	{ tput setaf 3; echo "* WARNING: $*" ; tput sgr0;	}
echo_info()	{ tput setaf 6; echo "* INFO: $*" ; tput sgr0;		}
echo_ok()	{ tput setaf 2; echo "* OK" ; tput sgr0;		}

if [[ "${1:-NOP}" == "NOP" ]]; then
    usage
    exit 1
fi

main "$@"

## EOF ##
