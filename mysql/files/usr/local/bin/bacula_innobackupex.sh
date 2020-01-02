#!/bin/bash
shopt -s extglob
#
# innobackupex wrapper for using with bacula
# Written by nbw
# Version 0.4.5
# 

# 
readonly PERC_PLUS=5

# Backup directory
readonly XBDIR=/var/preserve/xtrabackup
declare BASEDIR=$XBDIR/FULL

readonly CREDFILE=/root/.mypass
# Log file
readonly LOGFILE=/var/log/innobackupex.log
# MySQL configuration file
readonly -a MYCNF=(
    "/etc/opt/rh/rh-mariadb102/my.cnf.d/mariadb-server.cnf"
    "/etc/opt/rh/rh-mariadb101/my.cnf.d/mariadb-server.cnf"
    "/etc/opt/rh/rh-mariadb100/my.cnf.d/mariadb-server.cnf"
    "/etc/my.cnf"
    "/etc/mysql/my.cnf"
    )

PATH=/bin:/usr/bin:/sbin:/usr/sbin
bn="$(basename "$0")"

typeset -i PREPARE=0
typeset -i RESTORE=0
typeset -i KEEPOLD=0
typeset -i DEBUG=0
typeset -i FLUSH=0
typeset DEFAULTS="" DATADIR="" SOCKET=""

Main() {
    # Проверка, воскрес ли Христос
    chkXB

    local f=""
    # Условие для нахождения файла конфигурации my.cnf
    if [[ -z "$DEFAULTS" ]]; then
        for f in "${MYCNF[@]}"; do
            if [[ -f "$f" ]]; then
                DEFAULTS="$f"
                break
            fi
        done
    fi

    if [[ -z $DEFAULTS ]]; then
        writeLog "ERROR: my.cnf not found"
        exit 131
    fi

    if [[ -z "$DATADIR" ]]; then
	DATADIR=$(awk 'BEGIN { FS = "=" } /datadir/ { gsub(/[[:space:]]/, ""); print $2 }' "$DEFAULTS")
    fi

    if [[ -z "$DATADIR" ]]; then
	writeLog "ERROR: \"datadir\" option missing or not understood"
	exit 132
    fi

    if (( PREPARE == 1 )); then
	prepareIncrementalBackup
    elif (( RESTORE == 1 )); then
	restoreBackup
    elif (( FLUSH == 1 )); then
	flushBackup
    elif typeDecision2; then
	backupFull
	exit $?
    else
	backupIncremental
	exit $?
    fi

}

tailString() {
    FN=${FUNCNAME[0]}

    if tail -n2 $LOGFILE|grep -qF "completed OK"; then
	writeLog "completed OK"
    else
	writeLog "Some error occured, see $LOGFILE for details"
	exit 1
    fi
}

chkXB() {
    local prg=""

    for prg in innobackupex rsync bc; do
        if command -v $prg >/dev/null 2>&1; then
            continue
        else
            writeLog "ERROR: $prg not installed."
            exit 1
        fi
    done
}

credLoad() {
    # Подгружаем файлик с учётными данными
    if [ -f "$CREDFILE" ]; then
# shellcheck disable=SC1090
	. "$CREDFILE"
    else
	writeLog "ERROR: Credentials file not found"
	exit 134
    fi
}

# Backup type decision
# - определяем тип бэкапа: если первый Пн месяца - возвращаем 0,
# если каталог FULL отсутствует - тоже 0, иначе - 1
# Функция имеет только историческое значение; начиная с версии 0.3.6
# уровень бэкапа задаётся параметром "-l LEVEL"
typeDecision() {
    # Define array ( day-of-week day-of-month )
    local -a Day=()
    mapfile -t Day < <(date '+%u %d')
    # Если Пн
    if (( Day[0] == 1 )); then
	# и если входит в первые 7 дней
	if (( Day[1] <= 7 )); then
	    return 0
	fi
    fi

    local -a xdirs=()
    mapfile -t xdirs < <(ls -tr $XBDIR)
    (( DEBUG == 1 )) && echo "xdirs: \"${xdirs[*]}\"; #: \"${#xdirs[@]}\""

    if [ ! -d "$XBDIR" ]; then
	return 0
    elif (( ${#xdirs[@]} == 0 )); then
	return 0
    else
	return 1
    fi
}

typeDecision2() {
    writeLog "INFO: LEVEL=\"$LEVEL\""

    if [[ $LEVEL = "Full" ]]; then
	return 0
    elif [[ "$LEVEL" = "Incremental" || "$LEVEL" = "Инкрементальный" ]]; then
	# Проверка на пустоту/существование каталога с бэкапами 
	# (http://www.cyberciti.biz/faq/linux-unix-shell-check-if-directory-empty/)
	if [[ "$(ls -A $XBDIR 2>>$LOGFILE)" ]]; then
	    return 1
	else
	    writeLog "WARNING: Backup catalog not found/is empty, upgrade to Full"
	    mkdir -p "$XBDIR"
	    return 0
	fi
    else
	writeLog "ERROR: Unknown or wrong backup level"
	exit 112
    fi
}

backupFull() {

    diskSpaceChk
    credLoad

    FN=${FUNCNAME[0]}

    rm -r $XBDIR 2>>$LOGFILE
    mkdir -p $XBDIR 2>>$LOGFILE

    writeLog "INFO: performing full backup"
    (( DEBUG == 1 )) && echo "Commandline: innobackupex --defaults-file=$DEFAULTS --user=$MUSER --password=$MPASS --rsync --no-timestamp $BASEDIR >>$LOGFILE 2>&1"
    innobackupex --defaults-file="$DEFAULTS" ${SOCKET:+--socket="$SOCKET"} \
      --user="$MUSER" --password="$MPASS" --rsync --no-timestamp "$BASEDIR" >>$LOGFILE 2>&1
    except
    tailString
}

backupIncremental() {

    diskSpaceChk
    credLoad

    FN=${FUNCNAME[0]}

    cd $XBDIR || exit 1
    except
    # Помещаем список каталогов в массив
    local -a xdirs=()
    mapfile -t xdirs < <(ls -tr)
    (( DEBUG == 1 )) && echo "xdirs: \"${xdirs[*]}\""
    # Для инкрементального бэкапа базовым должен быть самый новый каталог
    BASEDIR=${xdirs[$(( ${#xdirs[@]} - 1 ))]}

    writeLog "INFO: performing incremental backup"
    innobackupex --defaults-file="$DEFAULTS" ${SOCKET:+--socket="$SOCKET"} \
      --user="$MUSER" --password="$MPASS" --rsync --incremental "$XBDIR" --incremental-basedir="$BASEDIR" >>$LOGFILE 2>&1
    except
    tailString
    # После отработки удаляем всё, кроме последнего свежесозданного каталога, который сожрёт Bacula
    (( KEEPOLD == 1 )) || rm -r "${xdirs[@]}"
}

prepareIncrementalBackup() {
    FN=${FUNCNAME[0]}

    cd $XBDIR || exit 1
    except
    # Помещаем список каталогов в массив
    local -a xdirs=()
    mapfile -t xdirs < <(ls)

    BASEDIR=${xdirs[$(( ${#xdirs[@]} - 1 ))]}
    if [ "$BASEDIR" != "FULL" ]; then
	writeLog "ERROR: Base backup directory not found."
	exit 1
    else
	writeLog "INFO: Preparing $BASEDIR"
	innobackupex --apply-log --redo-only "${PWD}/$BASEDIR" >$LOGFILE 2>&1
	except
	tailString
    fi
    # Удаляем хвостовой элемент массива, сохраненный в переменную BASEDIR
    unset xdirs[$(( ${#xdirs[@]} - 1 ))]
    # Последний каталог с инкрементальным бэкапом
    LAST_INCR=${xdirs[$(( ${#xdirs[@]} - 1 ))]}
    # Удаляем хвостовой элемент массива, сохраненный в переменную выше
    unset xdirs[$(( ${#xdirs[@]} - 1 ))]
    # Применяем оставшиеся элементы
    for dir in "${xdirs[@]}"; do
	# Пропускаем базовый каталог
	if [ "$dir" = "FULL" ]; then
	    continue
	fi
	writeLog "INFO: Preparing $dir"
	innobackupex --apply-log --redo-only "${PWD}/$BASEDIR" --incremental-dir="${PWD}/$dir" >>$LOGFILE 2>&1
	except
	tailString
    done
    # Применяем последний элемент
    # Пропускаем базовый каталог, если он и есть последний элемент (это, несомненно, баг,
    # такого быть не должно, однако, было; да и хер с ним)
    if [ "$LAST_INCR" = "FULL" ]; then
	writeLog "WARNING: last element proved FULL"
	return
    else
	writeLog "INFO: Preparing $LAST_INCR (tail)"
	innobackupex --apply-log "${PWD}/$BASEDIR" --incremental-dir="${PWD}/$LAST_INCR" >>$LOGFILE 2>&1
	except
	tailString
    fi
}

restoreBackup() {
    FN=${FUNCNAME[0]}

    typeset -a datadircontent=()
    mapfile -t datadircontent < <(ls "$DATADIR")
    (( DEBUG )) && echo "datadircontent: ${datadircontent[*]}"

    if (( ${#datadircontent[@]} != 0 )); then
	writeLog "ERROR: The datadir must be empty; Percona XtraBackup innobackupex --copy-back option will not copy over existing files."
	exit 128
    fi

    typeset -i MYSQLDPID=$(pidof -s mysqld)
    (( DEBUG )) && echo "MYSQLDPID: \"$MYSQLDPID\""

    if (( MYSQLDPID )); then
	writeLog "ERROR: MySQL server needs to be shut down before restore is performed."
	exit 129
    fi

    writeLog "INFO: Restoring from $BASEDIR"
    innobackupex --defaults-file="$DEFAULTS" --copy-back "$BASEDIR" >>$LOGFILE 2>&1
    except
    tailString

    writeLog "INFO: Running chown"
    chown -R mysql:mysql "$DATADIR"
    except
}

# Функция для ClientRunAfterJob,
# удаляет файлы баз из остающегося каталога
# для уменьшения занимаемого места
flushBackup() {
    FN=${FUNCNAME[0]}

    cd $XBDIR || exit 1
    except
    # Помещаем список каталогов в массив
    local -a xdirs=()
    mapfile -t xdirs < <(ls -tr)
    # Идём в последний по времени каталог
    cd "${xdirs[$(( ${#xdirs[@]} - 1 ))]}" || exit 1
    # Удаляем всё, кроме файлов описания бэкапа
    writeLog "INFO: Removing data files from ${PWD}: $(ls -dm !(xtrabackup*|backup-my.cnf))"
    rm -r !(xtrabackup*|backup-my.cnf)
    except
}
# Проверка наличия свободного места для бэкапа
diskSpaceChk() {
    FN=${FUNCNAME[0]}

    local fs=""
    local -i mysize=0 required_size=0

    mysize=$(du -s "$DATADIR" | awk '{print $1}')
    except
    required_size=$(echo "${mysize}+(${mysize}/100*${PERC_PLUS})"|bc)
    except
    local -i real_size=0

    for fs in '/var/preserve$' '/var$' '/$'; do
        real_size=$(df -P | awk -v "fs=$fs" '$0 ~ fs {print $4}')
        (( real_size != 0 )) && break
    done

    if (( real_size < required_size )); then
        writeLog "ERROR: Not enough disk space ($real_size real, $required_size required)"
        exit 1
    fi

}

except() {
    RET=$?
    if (( RET != 0 )); then
        writeLog "Error in function ${FN}, exit code $RET"
        exit $RET
    fi
}

writeLog() {
    echo "$*" | tee -a $LOGFILE
    logger -t "$bn" "$*"
}

usage() {
    echo -e "Usage: $bn option (REQUIRED)
        Options:
        -d          debug output
        -f <str>    --defaults-file for innobackupex
        -k          keep (don't delete) previous backup dirs on the disk
        -l <str>    backup level
	-m <str>    specify (apparently) mysql datadir
        -p          prepare incremental backup
        -r          restore backup
        -s <str>    specify (apparently) mysql socket
        -x          delete unnecessary files
        -h          print this help

        options -l, x, p[r] is mutually exclusive.
        "
}

while getopts "df:kl:m:prs:xh" OPTION; do
    case $OPTION in
        d) DEBUG=1
            ;;
        f) DEFAULTS=$OPTARG
            ;;
        k) KEEPOLD=1
            ;;
        l) LEVEL=$OPTARG
            ;;
	m) DATADIR=$OPTARG
	    ;;
        p) PREPARE=1
            ;;
        r) RESTORE=1
            ;;
	s) SOCKET=$OPTARG
	    ;;
        x) FLUSH=1
            ;;
        h) usage
            exit 0
            ;;
        *) usage
            exit 1
    esac
done

if [[ -z $1 ]]; then
    usage
    exit 1
fi

Main

#
# Changelog
#
# v. 0.3.8 2015-10-28
#       - disk space check added
#
# v. 0.4.1 2015-11-16
#       - fixed my.cnf search
#
# v. 0.4.2 2015-11-16
#       - added '-P' key to df
#
# v. 0.4.3 2017-08-13
#       - multile fixes in/for restoreBackup
#
# v. 0.4.4 2020-01-01
#       - fixes for use in ansible role 'mysql'
#
