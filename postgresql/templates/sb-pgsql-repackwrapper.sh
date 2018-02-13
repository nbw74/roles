#!/bin/bash
#
# Wrapper script for pg_repack
# Southbridge LLC, 2017 A.D.
#

set -E
set -o nounset

# CONSTANTS BEGIN
readonly PATH=/usr/pgsql-{{ postgresql_version_raw }}/bin:/bin:/usr/bin:/sbin:/usr/sbin
{% raw %}
readonly CONFIG_PATH=/usr/local/etc:/srv/southbridge/etc
readonly bn="$(basename $0)"
readonly LOGERR=$(mktemp --tmpdir ${bn%\.*}.XXXX)
readonly CONFIG=${bn%\.*}.conf
readonly BIN_REQUIRED="logger mailx pg_repack pidof"
# CONSTANTS END

# DEFAULTS BEGIN
typeset RUNUSER="postgres"
typeset MAILXTO="root"
typeset MAIL_SUBJ="ERRORS REPORTED: PostgreSQL pg_repack error Log"
typeset -i FREE_SPACE_THRESHOLD_MB=500
typeset -i FREE_SPACE_SCALE_FACTOR=2
typeset -i WAIT_TIMEOUT_SECS=60
# DEFAULTS END

typeset -i VERBOSE=0 NOMAIL=0 config_present=0
typeset -a TBL=()
typeset DB=""

main() {
    local fn=$FUNCNAME
    local -i free_bytes=0 total_relsize=0 required_space=0

    trap 'except $LINENO' ERR
    trap myexit EXIT

    checks

    for path in $(echo "$CONFIG_PATH"|tr ':' ' '); do
        if [[ -f "${path}/$CONFIG" ]]; then
            source "${path}/$CONFIG"
        fi
    done

    free_bytes=$(_get_free_space)
    if_zero $free_bytes "Cannot get free space"
    (( VERBOSE )) && echo "free_bytes, MB: $(( free_bytes / 1048576 ))"

    for (( i=0; i < ${#TBL[@]}; i++ )); do
        total_relsize=$(_get_pg_data "SELECT pg_total_relation_size('${TBL[$i]}')" "$DB")
        if_zero $total_relsize "Cannot get relation size"
        (( VERBOSE )) && echo "relation: '${TBL[$i]}', total_relsize, MB: $(( total_relsize / 1048576 ))"

        required_space=$(( total_relsize * FREE_SPACE_SCALE_FACTOR + FREE_SPACE_THRESHOLD_MB * 1048576 ))
        (( VERBOSE )) && echo "relation: '${TBL[$i]}', required_space, MB: $(( required_space / 1048576 ))"

        if (( free_bytes < required_space )); then
            echo "Not enough free disk space for pg_repack" >>$LOGERR
            false
        fi

        TBL[$i]="-t ${TBL[$i]}"
    done

    (( VERBOSE )) && echo "Run subshell for terminating of the waiting transactions"

    (
        # CONSTANTS BEGIN
        local -ir tail_lines=100
        local -ir iteration_seconds=10
        # CONSTANTS END

        local -i last_pid=0
        local -i tail_lines_with_last_pid=0
        local -i pg_repack_pid=0
        local -i it_is_not_a_first_iteration=0
        local -i lines_total=0
        local -i lines_total_prev=0

        while true; do
            if [[ -f $LOGERR ]]; then
                # Последнее поле последней строки
                last_pid=$(awk 'END { if ( $NF ~ /^[0-9]+$/ ) print $NF; else print 0; }' $LOGERR)
            else
                break
            fi
            # Если PID'а там не обнаружено
            if (( ! last_pid )); then
                # и текущая итерация - не первая
                if (( it_is_not_a_first_iteration )); then
                    pg_repack_pid=$(pidof -s pg_repack|cat)
                    # и нет процесса pg_repack, то выходим
                    if (( ! pg_repack_pid )); then
                        break
                    fi
                fi
                # иначе спим и возвращаемся к началу
                sleep $iteration_seconds
                it_is_not_a_first_iteration=1
                continue
            fi
            # Количество строк в последних $tail_lines, содержащих $last_pid
            tail_lines_with_last_pid=$(tail -n $tail_lines $LOGERR|fgrep $last_pid|wc -l)
            # Если эти значения равны друг другу...
            if (( tail_lines_with_last_pid == tail_lines )); then
                lines_total_prev=$lines_total
                lines_total=$(cat $LOGERR|wc -l)
                # И если со времени предыдущего убийства кол-во строк в файле изменилось
                # - прерываем $last_pid
                if (( lines_total != lines_total_prev )); then
                    _get_pg_data "SELECT pg_terminate_backend($last_pid);" >>$LOGERR
                fi
            fi
            # Ждём
            sleep $iteration_seconds
            it_is_not_a_first_iteration=1

            pg_repack_pid=$(pidof -s pg_repack|cat)
            # Если процесса уже нет - выходим
            if (( ! pg_repack_pid )); then
                break
            fi
        done
    ) &

    (( VERBOSE )) && echo "TBL: ${TBL[@]}"

    pg_repack -T $WAIT_TIMEOUT_SECS -d $DB ${TBL[@]} 2>>$LOGERR
}

_get_pg_data() {
    local fn=$FUNCNAME

    psql -AXqtc "$1" "${2:-postgres}" 2>>$LOGERR
}

_get_free_space() {
    local fn=$FUNCNAME
    local datadir="" fs=""
    local -i free_kb=0

    datadir=$(_get_pg_data "SHOW data_directory;")
    if_null "$datadir" "Cannot get postgresql data directory"

    _get_filesystem
    if_null "$fs" "Cannot get filesystem"

    free_kb=$(df -P | awk -v fs="^$fs" '$0 ~ fs { sub(/%/, ""); print $4 }')
    if_zero $free_kb "Cannot determine free space for '$datadir'"

    printf "%i" $(( free_kb * 1024 ))
}

_get_filesystem() {
    local fn=$FUNCNAME
    local check_path=$datadir
    local -i loop=0

    while true; do

        if (( loop > 10 )); then
            echo "Infinite loop apparently occured: cannot find filesystem" >>$LOGERR
            false
        fi

        fs=$(df -P | awk -v path="$check_path" '$6 == path { print $1 }')

        if [[ -z "$fs" ]]; then
            check_path=${check_path%\/*}
            [[ -z "$check_path" ]] && check_path="/"
        else
            break
        fi

        loop=$(( loop + 1 ))
    done
}

checks() {
    local fn=$FUNCNAME
    local -i pg_repack_pid=0

    if [[ $(whoami) != $RUNUSER ]]; then
        echo "This script must be run as '$RUNUSER' user" >>$LOGERR
        false
    fi

    for i in $BIN_REQUIRED; do
        if ! hash $i 2>/dev/null
        then
            echo "Required binary '$i' is not installed" >>$LOGERR
            false
        fi
    done

    if [[ ${#TBL[@]} == 0 || -z $DB ]]; then
        echo "Required parameter missing" >>$LOGERR
        false
    fi

    if [[ $(_get_pg_data "SELECT pg_is_in_recovery()") == t ]]; then
        (( VERBOSE )) && echo "Recovery state, exiting"
        exit 0
    fi

    pg_repack_pid=$(pidof -s pg_repack|cat)

    if (( pg_repack_pid )); then
        echo "pg_repack already running" >>$LOGERR
        false
    fi
}

if_zero() {
    local -i arg1=$1
    local arg2="$2"

    if (( ! arg1 )); then
        echo "$arg2" >>$LOGERR
        false
    fi
}

if_null() {
    local arg1="$1"
    local arg2="$2"

    if [[ -z $arg1 ]]; then
        echo "$arg2" >>$LOGERR
        false
    fi
}

except() {
    local ret=$?
    local no=${1:-no_line}

    if (( ! NOMAIL )); then
        echo -e "\tПроизошла ошибка при выполнении скрипта ${0} (строка ${no}, функция '$fn'), 
выполняющего сжатие таблиц СУБД PostgreSQL посредством команды pg_repack.
\tВывод сбойной команды:\n\n  $(cat ${LOGERR}|awk '$1=$1' ORS=' ')" | mailx -s "$MAIL_SUBJ" $MAILXTO
    fi

    if [[ -t 1 ]]; then
        echo "* FATAL: error occured in function '$fn' on line ${no}. Output: '$(cat ${LOGERR}|awk '$1=$1' ORS=' ')'" 1>&2
    fi

    logger -p user.err -t "$bn" "* FATAL: error occured in function '$fn' on line ${no}. Output: '$(cat ${LOGERR}|awk '$1=$1' ORS=' ')'"
    exit $ret
}

myexit() {
    local ret=$?

    [[ -f $LOGERR ]] && rm "$LOGERR"
    exit $ret
}

usage() {
    echo -e "\tUsage: $bn [-v] -d database -t table_name [ -t table_name ... ]\n
\t-d db_name\t\tSpecifies the name of the database to be reorganized.
\t-t [schema.]table_name\tReorganize the specified table(s). Multiple tables may be reorganized by writing multiple -t switches.
\t-v\t\t\tVerbose mode
\t-h\t\t\tPrint this help.
\n\tThis script must be run as 'postgres' user.
"
}

while getopts "d:t:hvM" OPTION; do
    case $OPTION in
        d) DB=$OPTARG
            ;;
        t) TBL+=("$OPTARG")
            ;;
        v) VERBOSE=1
            ;;
        M) NOMAIL=1
            ;;
        h) usage; exit 0
    esac
done

if [[ "${1:-NOP}" == "NOP" ]]; then
    usage
    exit 1
fi

main

{% endraw %}
## EOF ##
