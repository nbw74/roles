#!/bin/bash
#
# Backup VM image to remote host over SSH
# by nbw, 2018 A.D.
#

set -o nounset
set -o errtrace
set -o pipefail
# set -xv

# DEFAULTS BEGIN
typeset -i DEBUG=0 IGNORE_POWEROFF=0 SHUTDOWN=0 LOCAL=0
typeset -i BACKUP_DEPTH=3 SNAPSHOT_SIZE=10
typeset REMOTE_USER=$(whoami)
typeset REMOTE_HOST="" BASEDIR="" DEVICE=""
# DEFAULTS END

# CONSTANTS BEGIN
readonly PATH=/bin:/usr/bin:/sbin:/usr/sbin
readonly bn="$(basename "$0")"
readonly LOGERR=$(mktemp --tmpdir "${bn%\.*}.XXXX")
readonly BIN_REQUIRED="virsh lbzip2"
readonly LANG=C LC_ALL=C
readonly domain_shutdown_timeout=300
# CONSTANTS END

main() {
    local fn=${FUNCNAME[0]}

    trap 'except $LINENO' ERR
    trap _exit EXIT
    local -i frozen=0 snapshotted=0

    if (( ! DEBUG )); then
	exec 4>&2		# Link file descriptor #4 with stderr. Preserve stderr
	exec 2>>"$LOGERR"	# stderr replaced with file $LOGERR
    fi

    checks "${1:-nop}"

    if (( ! LOCAL )); then
	local connect="ssh -o PasswordAuthentication=no ${REMOTE_USER}@$REMOTE_HOST"
    fi

    while (( $# )); do

	local backup_dir="" domain="" device=""
	local -i blk_count=0

	domain="$1"
	backup_dir="${BASEDIR}/$domain"
	(( DEBUG )) && echo "* DEBUG: domain=$domain backup_dir=$backup_dir"

	removeOld

	if [[ -z "$DEVICE" ]]; then
	    # Get first block device
	    device=$(virsh domblklist "$domain"|awk '/[sv]d[a-z]/ { print $2; exit }')
	else
	    if [[ -b "$DEVICE" ]]; then
		device="$DEVICE"
	    else
		echo "Path '$DEVICE' is not a block device" >&2
		false
	    fi
	fi
	# Sanity checks
	blk_count=$(virsh domblklist "$domain" | grep -c '[sv]d[a-z]')
	if (( blk_count != 1 )); then
	    echo "Insufficient disks count for domain $domain (${blk_count}), must be 1" >&2
	    false
	fi
	if ! file -L "$device"|grep -q 'block special'; then
	    echo "VM disk $device is not a LVM volume, cannot continuing" >&2
	    false
	fi

	if (( SHUTDOWN )); then
	    backupShutdown
	else
	    backupSnapshot
	fi

	logInfo "backup finished"
	shift
    done

    exit 0
}

removeOld() {
    local fn=${FUNCNAME[0]}

    if (( LOCAL )); then
	if [[ -d "$backup_dir" ]]; then
	    logInfo "pruning old backups"
	    cd "$backup_dir" || false
	    find . -maxdepth 1 -mindepth 1 -type f -printf '%P\n' | sort -r | tail -n +$BACKUP_DEPTH | xargs -r rm --
	else
	    mkdir "$backup_dir"
	fi
    else
	if $connect "test -d '$backup_dir'"; then
	    logInfo "pruning old backups"
	    $connect "cd '$backup_dir' && find . -maxdepth 1 -mindepth 1 -type f -printf '%P\n' | sort -r | tail -n +$BACKUP_DEPTH | xargs -r rm --"
	else
	    $connect "mkdir '$backup_dir'"
	fi
    fi
}

backupShutdown() {
    local fn=${FUNCNAME[0]}

    if is_poweroff; then
	if (( ! IGNORE_POWEROFF )); then
	    echo "VM is already powered off, maybe backup is not needed?" >&2
	    false
	fi
    else
	logInfo "domain shutdown"
	virsh -q shutdown "$domain"
    fi
    # Waiting for VM shutdown
    i=0
    until is_poweroff; do
	sleep 1
	i=$(( i+1 ))
	(( DEBUG )) && echo -n "$i "
	if (( i > domain_shutdown_timeout )); then
	    echo "Domain shutdown timeout reached ($domain_shutdown_timeout)." >&2
	    false
	fi
    done
    (( DEBUG )) && echo

    makeDump "$device"

    logInfo "domain starting"
    virsh -q start "$domain"
}

is_poweroff() {
    local fn=${FUNCNAME[0]}

    if [[ $(virsh domstate "$domain"|head -1|sed -r 's/\s+$//') == "shut off" ]]; then
	return 0
    else
	return 1
    fi
}

backupSnapshot() {
    local fn=${FUNCNAME[0]}
    local snapshot="" snapshot_basename=""

    snapshot="${device}_snap"
    snapshot_basename=$(basename "$snapshot")

    if [[ -b "$snapshot" ]]; then
	echo "Snapshot $snapshot already exists, terminating." >&2
	false
    fi

    logInfo "freezing filesystem"
    virsh -q domfsfreeze "$domain"
    frozen=1

    logInfo "creating ${SNAPSHOT_SIZE}G snapshot"
    lvcreate -qq --size ${SNAPSHOT_SIZE}G --snapshot --name "$snapshot_basename" "${device}"
    snapshotted=1

    frozen=0
    logInfo "thawing filesystem"
    virsh -q domfsthaw "$domain"

    makeDump "$snapshot"

    snapshotted=0
    logInfo "removing snapshot"
    lvremove -qqf "$snapshot"
}

makeDump() {
    local fn=${FUNCNAME[0]}
    local dev=$1

    if (( LOCAL )); then
	logInfo "dump to local server"
	ionice -c3 dd if="$dev" bs=8M | nice lbzip2 - | dd of="${backup_dir}/$(date +'%s')-${domain}.img.bz2" bs=8M
    else
	logInfo "dump to remote server"
	ionice -c3 dd if="$dev" bs=8M | nice lbzip2 - | $connect "dd of=${backup_dir}/$(date +'%s')-${domain}.img.bz2 bs=8M"
    fi
}

logInfo() {
    local fn=${FUNCNAME[0]}

    logger -p user.info -t "$bn" "* INFO: ${domain}: $*"
}

checks() {
    local fn=${FUNCNAME[0]}
    # Required binaries check
    for i in $BIN_REQUIRED; do
        if ! command -v "$i" >/dev/null
        then
            echo "Required binary '$i' is not installed." >&2
            false
        fi
    done

    if (( UID )); then
	echo "this script must be run as superuser" >&2
	false
    fi

    if [[ "$1" == "nop" || -z $BASEDIR ]]; then
	echo "required parameter missing" >&2
	false
    fi

    if [[ $LOCAL == 0 && -z $REMOTE_HOST ]]; then
	echo "required parameter missing" >&2
	false
    fi
}

except() {
    local ret=$?
    local no=${1:-no_line}

    if [[ -t 1 ]]; then
        echo "* FATAL: error occured in function '$fn' near line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    fi

    logger -p user.err -t "$bn" "* FATAL: error occured in function '$fn' near line ${no}. Stderr: '$(awk '$1=$1' ORS=' ' "${LOGERR}")'"
    exit $ret
}

_exit() {
    local ret=$?

    if (( ! DEBUG )); then
	exec 2>&4 4>&-	# Restore stderr and close file descriptor #4
    fi

    if (( frozen )); then
	logInfo "thawing filesystem"
	virsh -q domfsthaw "$domain"
    fi

    if (( snapshotted )); then
	logInfo "removing snapshot"
	lvremove -qqf "$snapshot"
    fi

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\\nScript for KVM virtual machines backup.\\nOnly single-disk LV is currently supported
    Usage: $bn [OPTIONS] <parameter>\\n
    Options:

    -b, --basedir <path>	base directory for backups on remote or local host
    -d, --device <path>		manually set block device for backup
    -D, --depth <int>		backup depth (default is ${BACKUP_DEPTH})
    -H, --host <string>		remote host
    -U, --user <strng>		remote user
    -i, --ignore-poweroff	don't error if host is already powered off
    -l, --local			do local backup instead of remote
    -s, --shutdown		shut down VM before backup (instead of making snapshot)
    -S, --snapshot-size <int>	size of snapshot, GB (default is ${SNAPSHOT_SIZE})
    -d, --debug			print some info in stdout/stderr
    -h, --help			print help
"
}
# Getopts
getopt -T; (( $? == 4 )) || { echo "incompatible getopt version" >&2; exit 4; }

if ! TEMP=$(getopt -o b:d:D:H:S:U:ilsdh --longoptions basedir:,device:,depth:,host:,user:,ignore-poweroff,local,shutdown,snapshot-size:,debug,help -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
	-b|--basedir)		BASEDIR=$2 ;		shift 2	;;
	-d|--device)		DEVICE=$2 ;		shift 2	;;
	-D|--depth)		BACKUP_DEPTH=$2 ;	shift 2	;;
	-H|--host)		REMOTE_HOST=$2 ;	shift 2	;;
	-U|--user)		REMOTE_USER=$2 ;	shift 2	;;
	-i|--ignore-poweroff)	IGNORE_POWEROFF=1 ;	shift	;;
	-l|--local)		LOCAL=1 ;		shift	;;
	-s|--shutdown)		SHUTDOWN=1 ;		shift	;;
	-S|--snapshot-size)	SNAPSHOT_SIZE=$2 ;	shift 2	;;
	-d|--debug)		DEBUG=1 ;		shift	;;
	-h|--help)		usage ;		exit 0	;;
	--)			shift ;		break	;;
	*)			usage ;		exit 1
    esac
done

main "$@"

## EOF ##
