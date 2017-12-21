#!/bin/bash
#
{% if ansible_distribution_major_version|int > 6 %}
# Run script for {{ postgresql_iptables_service }}.service
# Southbridge LLC, 2017 A. D.
{% else %}
# {{ postgresql_iptables_service }}      Start iptables firewall custom chain for postgresql service
#
# chkconfig: 2345 09 91
# description:  Starts, stops and reload {{ postgresql_iptables_chain }} chain for iptables firewall
#
# config: {{ postgresql_sb_etc }}/{{ postgresql_iptables_config }}
#
### BEGIN INIT INFO
# Provides: {{ postgresql_iptables_service }}
# Required-Start: iptables
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: start and stop {{ postgresql_iptables_chain }} chain for iptables firewall
# Description: Start, stop and reload {{ postgresql_iptables_chain }} chain for iptables firewall
### END INIT INFO

# Source function library.
. /etc/init.d/functions
{% endif %}

set -o nounset
set -E

readonly PATH=/bin:/sbin:/usr/bin:/usr/sbin
readonly bn=$(basename $0)

# Configuration
readonly dstport={{ postgresql_conf['port']|default('5432') }}
readonly whitelist="{{ postgresql_sb_etc }}/{{ postgresql_iptables_config }}"
readonly chain="{{ postgresql_iptables_chain }}"
{% if ansible_distribution_major_version|int > 6 %}
readonly w="--wait"
{% else %}
readonly w=""
{% endif %}

trap except ERR

start() {
    local FN=$FUNCNAME

    if iptables-save | fgrep -q ":$chain"; then
        return
    else
        iptables $w -N $chain
        reload
    fi
}

reload() {
    local FN=$FUNCNAME

    if [[ ! -f "$whitelist" ]]; then
        echo "${bn}: main configuration file is missing" 1>&2
        false
    fi

    if ! iptables-save | fgrep -q ":$chain"; then
        echo "${bn}: chain '$chain' not found" 1>&2
        false
    fi

{% if ansible_distribution_major_version|int < 7 %}
    echo -n $"{{ postgresql_iptables_service }}: Applying firewall rules: "
{% endif %}
    iptables $w -F $chain
    iptables $w -A $chain -m addrtype --src-type LOCAL -j ACCEPT

    for src in $(egrep -v '^#|^$|^\s+$' $whitelist | awk '{ print $1 }' | sort | uniq); do
        iptables $w -A $chain -s $src -j ACCEPT
    done

    iptables $w -A $chain -j REJECT --reject-with icmp-host-prohibited
    removejump
    iptables $w -I INPUT $(find_insert_position) -m tcp -p tcp --dport $dstport -j $chain
{% if ansible_distribution_major_version|int < 7 %}
    success; echo
{% endif %}
}

removejump() {
{% if ansible_distribution_major_version|int > 6 %}
    iptables-save | awk -v chain="-j $chain" '$0 ~ chain { sub(/-A/, "-D"); system("iptables --wait "$0) }'
{% else %}
    iptables-save | awk -v chain="-j $chain" '$0 ~ chain { sub(/-A/, "-D"); system("iptables "$0) }'
{% endif %}
}

# Если есть правило с ESTABLISHED - то вставляем после него, если нет - в начало
find_insert_position() {
    local FN=$FUNCNAME
    local -i pos=0

    pos=$(iptables-save -t filter | fgrep -- '-A INPUT' | awk '/ESTABLISHED/ { print NR + 1; exit }')

    if (( pos )); then
        printf "%i" $pos
    else
        printf "%i" 1
    fi
}

stop() {
{% if ansible_distribution_major_version|int < 7 %}
    echo -n $"{{ postgresql_iptables_service }}: Unloading firewall rules: "
{% endif %}
    removejump
    iptables $w -F $chain 2>/dev/null || true
    iptables $w -X $chain 2>/dev/null || true
{% if ansible_distribution_major_version|int < 7 %}
    success; echo
{% endif %}
}

status() {
    local FN=$FUNCNAME

    if iptables-save | fgrep -q ":$chain"; then
        iptables $w -t filter -n -v -L $chain
    else
        echo "${bn}: chain '$chain' not found" 1>&2
        exit 1
    fi
}

except() {
    local RET=$?

{% if ansible_distribution_major_version|int < 7 %}
    failure; echo;
{% endif %}
    stop
    echo "ERROR: service $bn failed in function '$FN'" 1>&2
    exit $RET
}

usage() {
    echo "Usage: $bn start | stop | reload | restart | status"
}

case "${1:-NOP}" in
    start) start
        ;;
    stop) stop
        ;;
    reload) reload
        ;;
    restart) stop; start
        ;;
    status) status
        ;;
    *) usage
esac

exit 0

