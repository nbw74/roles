#!/bin/bash
#
# Скрипт для инициализации пользователя
# БД MySQL/PgSQL на выделенном сервере
# v. 0.1.0
# 

. /etc/rc.d/init.d/functions

typeset -i MdbNameMaxLength=13
typeset -i PdbNameMaxLength=62

bn=$(basename "$0")

set -o nounset
set -o errtrace

typeset -i REMOVE=0 CREATE_RO=0 NOUSER=0 warn=0

typeset CHARSET="utf8"
typeset COLLATE="utf8_general_ci"

typeset DBMS="" DBHOST="" DBUSER="" PASSWD="" DBCREDS="" DBCREDS_RO=""
typeset authParams=""
typeset DBPORT=""
typeset mysql_bin=""

trap except ERR
# Не работает эта хуйня
# trap 'prev_cmd=$cmd; cmd=$BASH_COMMAND' DEBUG

Main() {
    FN=${FUNCNAME[0]}
    local -i dbtype=0

    if [[ $DBMS =~ mysql|m ]]; then
        DBMS=MySQL
        dbtype=1
    elif [[ $DBMS =~ pgsql|psql|p ]]; then
        DBMS=PostgreSQL
        dbtype=2
    else
        echo "Required parameter missing" 1>&2
        except
    fi

    local db="${S_DBNAME:-NOP}"

    if [[ $db == "NOP" ]]; then
        echo "Required partameter missing"
        except
    fi

    if [[ ${DBUSER:-NOP} == "NOP" ]]; then
        DBUSER=$db
    fi

    if (( REMOVE == 0 )); then
        CreateDB
        Echo
    else
        RemoveDB
    fi

}

mdpass() {
    dd if=/dev/urandom bs=512 count=1 2>/dev/null | md5sum | awk '{print $1}';
}

CreateDB() {
    FN=${FUNCNAME[0]}

    
    if [[ ${PASSWD:-NOP} == "NOP" ]]; then
        mypass=$(mdpass)
        mypass_ro=$(mdpass)
    else
        mypass="$PASSWD"
        CREATE_RO=0
    fi

    if (( dbtype == 1 )); then
        createMy
    elif (( dbtype == 2 )); then
        createPg
    else
        echo "Internal error" 1>&2
        except
    fi

    if [[ -z ${DBHOST} ]]; then
        DBHOST=$(hostname -f)
    fi

    DBCREDS="
*DBMS:* @${DBMS}@
*DB host:* @${DBHOST}@
*DB port:* ${DBPORT}
*DB name:* @${db}@
*DB user:* @${DBUSER}:${mypass}@"

    if (( CREATE_RO == 1 )); then
        DBCREDS_RO="
*DB r/o user:* @${DBUSER}_ro:${mypass_ro}@"
    fi
}

findMy() {
    FN=${FUNCNAME[0]}

    # Find mysql executable
    # Fast and dirty

    local -a binaries=( "/opt/rh/rh-mariadb101/root/bin/mysql" "/opt/rh/rh-mariadb100/root/bin/mysql" "/usr/bin/mysql" )
    local i=0

    while true; do
        if [[ -x "${binaries[$i]}" ]]; then
            mysql_bin="${binaries[$i]}"
            break
        fi
        i=$((i+1))
    done

    if [[ -z $mysql_bin ]]; then
        echo "FATAL: mysql binary not found" 1>&2
        false || except
    fi

}

createMy() {
    FN=${FUNCNAME[0]}

    findMy

    echo -n "Creating MySQL database... "

    $mysql_bin $authParams -e "CREATE DATABASE ${db} CHARACTER SET ${CHARSET} COLLATE ${COLLATE};"

    if (( NOUSER == 0 )); then
        $mysql_bin $authParams "${db}" -e "CREATE USER '${DBUSER}'@'%' IDENTIFIED BY '${mypass}';"
    fi

    $mysql_bin $authParams "${db}" -e "GRANT ALL ON ${db}.* TO '${DBUSER}'@'%'; FLUSH PRIVILEGES;"

    if (( CREATE_RO == 1 )); then
        $mysql_bin $authParams "${db}" -e "CREATE USER '${DBUSER}_ro'@'%' IDENTIFIED BY '${mypass_ro}'; GRANT SELECT ON ${db}.* TO '${DBUSER}_ro'@'%'; FLUSH PRIVILEGES;"
    fi

    readonly DBPORT=${DBPORT:-@3306@}

    echo_success
    echo

}

createPg() {
    FN=${FUNCNAME[0]}

    if [[ -n "$DBHOST" ]]; then
        DBHOST="-h $DBHOST"
    fi

    if (( NOUSER == 0 )); then
        psql "$DBHOST" -U postgres -d postgres -c "CREATE ROLE $DBUSER LOGIN NOSUPERUSER UNENCRYPTED PASSWORD '${mypass}';"
    fi
    psql "$DBHOST" -U postgres -d postgres -c "CREATE DATABASE $db OWNER $DBUSER;"

    readonly DBPORT=${DBPORT:-@3306@}
}

chkNameLength() {
    FN=${FUNCNAME[0]}

    local -i dbNameMaxLength=0 len=0

    if (( dbtype == 1 )); then
        dbNameMaxLength=$MdbNameMaxLength
    elif (( dbtype == 2 )); then
        dbNameMaxLength=$PdbNameMaxLength
    else
        echo "Internal error" 1>&2
        except
    fi

    len=$(echo -n "$db"|wc -c)
    if (( len > dbNameMaxLength )); then
        echo "ERROR: database name length ($len) exceeds maximum ($dbNameMaxLength)." 1>&2
	except
    fi
}

Echo() {
    FN=${FUNCNAME[0]}

    # Wiki page generation

    echo "
#
# Wiki page:
#
===============================================================================

h3. Database
${DBCREDS}${DBCREDS_RO}

===============================================================================
#"

}

RemoveDB() {
    FN=${FUNCNAME[0]}
    warn=1

    if (( dbtype == 1 )); then
        findMy
        # Removing database
        if (( NOUSER == 0 )); then
            echo -n "Removing database user" "$DBUSER"
            $mysql_bin $authParams "${db}" -e "DROP USER '${DBUSER}'@'%'"
            echo_success
            echo
            if (( CREATE_RO == 1 )); then
                echo -n "Removing database user" "${DBUSER}_ro"
                $mysql_bin $authParams "${db}" -e "DROP USER '${DBUSER}_ro'@'%'"
                echo_success
                echo
            fi
        fi
        echo -n "Removing database" "$db"
        $mysql_bin $authParams "${db}" -e "DROP DATABASE $db"
        echo_success
        echo
    elif (( dbtype == 2 )); then
        if [[ -n "$DBHOST" ]]; then
            DBHOST="-h $DBHOST"
        fi

        psql "$DBHOST" -U postgres -c "DROP DATABASE $db"

        if (( NOUSER == 0 )); then
            psql "$DBHOST" -U postgres -c "DROP ROLE $DBUSER;"
        fi
    else
        echo "Internal error" 1>&2
        except
    fi

    warn=0
}

except() {
    RET=$?

    if (( warn == 1 )); then
        # echo -n "W: prev. command is \"$prev_cmd\""
        echo_warning
        echo
        return 0
    else
        echo -n "E: runtime error in function $FN"
        echo_failure
        echo
        exit $RET
    fi
}

usage() {
    echo -e "Usage: $bn <option(s)>
        Options:
        -b          print pgbouncer port (6432) in Wiki echo
        -c <COLLATE>    MySQL collate (default: utf8_general_ci)
        -d          database name (up to 12 chars) [REQUIRED]
        -e <CHARSET>    MySQL character set (default: utf8)
        -H          database host (PostgreSQL only)
        -p          password for db user. If defined, _ro user will not be created.
        -P          password for database root user
        -r          create additional readonly user
        -t          DBMS (mysql/pgsql, m/p) [REQUIRED]
        -u          database user (default = database name)
        -U          do not create user (if user already exist)
        -x          remove database and keys instead creation
        "
}

while getopts "bc:d:e:H:hp:P:rt:u:Ux" OPTION; do
    case $OPTION in
        b) DBPORT="%{color:darkred}@6432@%"
            ;;
        c) COLLATE=$OPTARG
            ;;
        d) S_DBNAME=$OPTARG
            ;;
        e) CHARSET=$OPTARG
            ;;
        H) DBHOST=$OPTARG
            ;;
        p) PASSWD=$OPTARG
            ;;
        P) authParams="-p$OPTARG"
            ;;
        r) CREATE_RO=1
            ;;
        t) DBMS=$OPTARG
            ;;
        u) DBUSER=$OPTARG
            ;;
        U) NOUSER=1
            ;;
        x) REMOVE=1
            ;;
        h) usage
            exit 0
            ;;
        *) usage
            exit 1
    esac
done

Main
