#!/bin/bash
#
# Simple wrapper for use ShellCheck and Ansible-lint with Gitlab-CI
# factory:254678
# Southbridge LLC, 2018 A.D.
# Webmechanic LLC, 2019 A.D.
#

set -E
set -o nounset

# CONSTANTS BEGIN
readonly PATH=/usr/local/bin:$PATH
readonly bn=$(basename "$0")
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly BIN_REQUIRED="shellcheck ansible-lint"
# CONSTANTS END

# DEFAULTS BEGIN
typeset EXCODES="${EXCLUDE_CODES:-SC1090}"
typeset -i MODE=0
# DEFAULTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT
# Required binaries check
    for i in $BIN_REQUIRED; do
        if ! hash "$i" 2>/dev/null
        then
            echo "Required binary '$i' is not installed" >"$LOGERR"
            false
        fi
    done

    local -a Filelist=()
    local -a Interested=()
    local -i found=0

    mapfile -t Filelist < <( git --no-pager show --format='' --name-only --no-color HEAD HEAD~1 HEAD~2 | sort -u )

    printf '%s\n' "==== Modified files in HEAD, HEAD~1, HEAD~2 (as given by 'git show'):"

    if [[ ${Filelist[*]:-nop} == "nop" ]]; then
	echo "==== WARNING: no files for check" >&2
	exit 0
    fi

    for i in "${Filelist[@]}"; do
        printf '%s\n' "$i"

        if _find "$i"
        then
            found=1
            Interested+=("$i")
        fi
    done

    if (( found )); then
        printf '%s\n' "==== Files for check:"
        printf '%s\n' "${Interested[@]}"
        printf '=%.0s' {1..80}; printf '\n'
	if (( ! MODE )); then
	    shellcheck --exclude="$EXCODES" --color=always "${Interested[@]}"
	elif (( MODE == 1 )); then
	    ansible-lint --force-color "${Interested[@]}"
	elif (( MODE == 2 )); then
	    yamllint -f colored "${Interested[@]}"
	fi
    else
        printf '%s\n' "==== No files for check."
    fi

    exit 0
}

_find() {
    local fn=${FUNCNAME[0]}

    if [[ ! -f "$1" ]]; then
	return 1;
    fi

    if (( ! MODE )); then
        if file "$1" | grep -Fq 'shell script'
        then
	    if grep -Fq '{{' "$1"
	    then
		return 1
	    else
		return 0
	    fi
        fi
    elif (( MODE == 1 )) || (( MODE == 2 )); then
        if [[ "$1" =~ \.y?ml$ ]]
        then
            return 0
        fi
    else
	printf '%s\n' "==== Unknown mode."
    fi

    return 1
}

except() {
    local ret=$?
    local no=${1:-no_line}

    echo "* FATAL: error occured in function '$fn' on line ${no}. Output: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'" 1>&2
    logger -p user.err -t "$bn" "* FATAL: error occured in function '$fn' on line ${no}. Output: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    exit $ret
}

_exit() {
    local ret=$?

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\\n    Usage: $bn [OPTIONS]\\n
    Options:

    -a, --ansible-lint		ansible-lint mode
    -s, --shellcheck		shellcheck mode (default)
    -y, --yamllint		yamllint mode
    -h, --help			print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o asyh --longoptions ansible-lint,shellcheck,yamllint,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-a|--ansible-lint)	MODE=1 ;	shift	;;
	-s|--shellcheck)	MODE=0 ;	shift	;;
	-y|--yamllint)		MODE=2 ;	shift	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

main

## EOF ##
