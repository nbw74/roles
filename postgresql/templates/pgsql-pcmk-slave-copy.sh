#!/bin/bash
# THIS FILE IS ANSIBLE MANAGED
#
# Script for copying data to PostgreSQL replica
# Southbridge LLC, 2017 A.D.
#

set -o nounset

arg1=${1:-NOP}

readonly pg_ver="{{ postgresql_version_raw  }}"
readonly preset_master_ip="{{ postgresql_pcmk_ip_repl }}"
readonly pgdata="/var/lib/pgsql/{{ postgresql_version_raw }}/data"
readonly lockfile="/var/lib/pgsql/{{ postgresql_version_raw }}/tmp/PGSQL.lock"
readonly authfile="/var/lib/pgsql/.pgpass"
readonly username=replicator
readonly master_port=5432

readonly BIN_REQUIRED="pidof tcping pg_basebackup pcs"

typeset master_ip="$preset_master_ip"
typeset -i CLEANUP=0

main() {
    local -i warn=0

    trap 'except $LINENO' ERR

    if [[ $arg1 == NOP ]]; then
        true
    elif [[ $arg1 =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4} ]]; then
        master_ip="$arg1"
    elif [[ $arg1 =~ ^(cleanup|c)$ ]]; then
        CLEANUP=1
    else
        echo_err "* ERROR: Parameter not recognized"
        false
    fi

    for i in $BIN_REQUIRED; do
        if ! hash "$i" 2>/dev/null
        then
            echo_err "* ERROR: Required binary '$i' is not installed"
            false
        fi
    done

    if [[ "$(whoami)" == "postgres" ]]; then
        readonly pg_sudo=""
    else
        readonly pg_sudo="sudo -iu postgres"
    fi

    if pidof "/usr/pgsql-${pg_ver}/bin/postgres" >/dev/null
    then
        echo_err "* ERROR: PostgreSQL server is running"
        false
    fi

    if ! tcping -q "${master_ip}" ${master_port} >/dev/null
    then
        echo_err "* ERROR: Replication socket is unreachable"
        false
    fi

    if ! $pg_sudo test -r "$authfile"
    then
        echo_err "* ERROR: '.pgpass' file is unreadable or missing"
        false
    else
        $pg_sudo chmod 0600 "$authfile"
    fi

    if ! $pg_sudo grep -Fq "$username" "$authfile"
    then
        echo_err "* ERROR: user data in missing in the $authfile"
        false
    fi

    echo_info "* INFO: Recreating instance data directory..."
    $pg_sudo rm -rf "$pgdata"
    $pg_sudo mkdir -m 0700 "$pgdata"

    echo_info "* INFO: Running pg_basebackup..."
    warn=1
    $pg_sudo pg_basebackup --host="$master_ip" --username="$username" --pgdata="$pgdata" --xlog-method=stream --status-interval=1 --progress
    warn=0

    if $pg_sudo test -f "$lockfile"
    then
        echo_warn "* WARN: Lock file found."
        $pg_sudo rm -v "$lockfile"
    fi

    if (( CLEANUP )); then
        warn=1
        echo_info "* INFO: cleanup current node errors"
        sudo pcs resource cleanup PGSQL --node "$(uname -n)"
        echo_info "* INFO: clear PGGSL constraint"
        sudo pcs resource clear PGSQL "$(uname -n)"
        warn=0
    fi

    echo_ok "* DONE"
}

echo_err() { $C_WHITE; echo "$@" 1>&2; $C_RST; }
echo_warn() { $C_YELLOW; echo "$@" 1>&2; $C_RST; }
echo_info() { $C_BLUE; echo "$@" 1>&2; $C_RST; }
echo_ok() { $C_GREEN; echo "$@" 1>&2; $C_RST; }

except() {
    local ret=$?

    if (( warn )); then
        echo_warn "* WARN: process exited with code '$ret'"
        return
    else
        $C_RED; echo "* FATAL: error occured on line ${1:-UNKNOWN}" 1>&2; $C_RST;
        exit $ret
    fi
}

readonly C_RST="tput sgr0"
readonly C_RED="tput setaf 1"
readonly C_GREEN="tput setaf 2"
readonly C_YELLOW="tput setaf 3"
readonly C_BLUE="tput setaf 4"
readonly C_WHITE="tput setaf 7"

main
