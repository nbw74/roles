#!/bin/bash
#
# Скрипт для инициализации пользователя bitrix
# на развёрнутом шаблоне bxInit
# v. 0.1.4
# 

. /etc/rc.d/init.d/functions

BASEDIR=/home
USER=bitrix
WEBROOT=www

bn=$(basename $0)
host=$(hostname -f)

set -o nounset

typeset -i NOECHO=0

Main() {
    FN=$FUNCNAME

    if grep -i centos /etc/issue >/dev/null; then
        authParams=""
    else
        echo "Current system is not a CentOS, exiting"
        false || except
    fi

    CreateKeys
    Echo

}


CreateKeys() {
    FN=$FUNCNAME

    echo -n "Creating RSA key..."

    # Создаём необходимые директории
    sudo -u ${USER} mkdir -p -m 700 $BASEDIR/${USER}/.ssh
    except quiet

    sudo -u ${USER} ssh-keygen -t rsa -q -f $BASEDIR/${USER}/.ssh/${USER}_rsa -N ""
    except quiet
    sudo -u ${USER} cp $BASEDIR/${USER}/.ssh/${USER}_rsa.pub $BASEDIR/${USER}/.ssh/authorized_keys
    except quiet
    sudo -u ${USER} chmod 600 $BASEDIR/${USER}/.ssh/authorized_keys
    except
}

Echo() {
    FN=$FUNCNAME

    if (( NOECHO == 1 )); then
        return
    fi

    # Wiki page generation
    local PRIVKEY="$(cat $BASEDIR/${USER}/.ssh/${USER}_rsa)"
    except quiet

    echo "
#
# Wiki page:
#
===============================================================================

h2. Сервер разработки

h3. Web

*URI:* http://$(hostname -f)
*Frontend:* @$(nginx -V 2>&1 | awk '/nginx version:/ { print $3 }')@
*Backend:* @$(httpd -V | awk '/Server version:/ { print $3 }') + $(php -v | awk '/PHP .* \(cli\)/ { print $1, $2 }')@
*Bitrix-env:* @$(rpm -q --qf "%{VERSION}-%{RELEASE}\n" bitrix-env)@

h3. SSH Access

*host:* @$host@
*user:* @$USER@
*private key:*{{collapse
<pre>$PRIVKEY</pre>
}}

===============================================================================
#"

}

except() {
    RET=$?
    opt1=${1:-NOP}
    opt2=${2:-NOP}

    if (( RET == 0 )); then
        if [[ $opt1 == "quiet" || $opt2 == "quiet" ]]; then
            return
	elif [[ $opt1 = "pass" ]]; then
	    echo_passed
	    echo
        else
            echo_success
	    echo
        fi
    else
        if [[ $opt1 == "warn" ]]; then
            echo_warning
            echo
        else
            echo -n "Runtime error in function $FN"
            echo_failure
            echo
            exit $RET
        fi
    fi
}

writeLog() {
    echo -e "$*" 1>&2
    logger -t "$bn" "$*"
}

usage() {
    echo -e "Usage: $bn <option(s)>
        Options:
        -E          suppress Wiki page print
        "
}

while getopts "d:xhDEK" OPTION; do
    case $OPTION in
        E) NOECHO=1
            ;;
        h) usage
            exit 0
                ;;
        *) usage
            exit 1
    esac
done

Main
