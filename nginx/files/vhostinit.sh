#!/bin/bash
#
# version 0.6.1
#

set -o errtrace



readonly bn=$(basename "$0")
readonly hn=$(hostname -f)

typeset keytype=ed25519

typeset -i NOSITE=0 NOUSER=0 NOECHO=0 NORELOAD=0 REMOVE=0 REMOVEALL=0
typeset -i NOSELINUX=0 SSL=0 NOAWSTATS=0 AWSTATSONLY=0 WEBINFO=0
typeset -i COPY_SSH_KEY=0 SUBDOMAIN=0 warn=0
typeset BACKEND="" OS="" FRONTENDUSER="" BACKENDUSER="" S_DOMAIN="" user="" WEBROOT=""
typeset BASEDIR=/var/www user="" siteroot=""

Main() {
    local FN=${FUNCNAME[0]}
    local utime="" uhash=""

    trap except ERR

    if [[ -z $S_DOMAIN ]]; then
        writeLog "FATAL: Required parameter is missing (-s)"
        false
    fi

    if grep -iq debian /etc/issue; then
        OS=debian
        FRONTENDUSER=www-data
        ECHOMSG=log_daemon_msg
        httpd_sites=/etc/apache2/sites-available
        nginx_sites=/etc/nginx/sites-available
    elif [[ -f /etc/centos-release || -f /etc/fedora-release ]]; then
        OS=centos
        FRONTENDUSER=nginx
        ECHOMSG="echo -n"
        httpd_sites=/etc/httpd/conf.d
        nginx_sites=/etc/nginx/conf.d
        fpm_d=/etc/php-fpm.d

        if [[ $BACKEND != "none" ]]; then
            BACKENDUSER=apache
        fi

        if (( ! NOSELINUX )); then
            if grep -Pq '^SELINUX.*=.*disabled' /etc/selinux/config; then
                NOSELINUX=1
            fi
        fi
    else
        echo "FATAL: Unknown operating system (only Debian & CentOS|Fedora supported)" >&2
        false
    fi

    if (( AWSTATSONLY )); then
        AwstatsConfig
        exit 0
    fi

    if [[ -z $BACKEND ]]; then
        writeLog "FATAL: Required parameter is missing (-b)"
        false
    else
        if [[ $BACKEND =~ httpd|apache2|php-fpm|fpm|none ]]; then
            if [[ $OS == "debian" && $BACKEND =~ php-fpm|fpm ]]; then
                writeLog "FATAL: Not supported"
                false
            fi
        else
            writeLog "FATAL: Unknown backend (${BACKEND})"
            false
        fi
    fi

    # Проверка существования домена
    if grep -RPq "\\s+${S_DOMAIN}" $nginx_sites
    then
        if (( ! REMOVE )); then
            writeLog "FATAL: collision: domain name already exists in the Nginx configuration"
            false
        fi
    fi

    readonly ipaddr="${S_IPADDR:-$S_DOMAIN}"
    # Если имя пользователя для сайта не задано, рожаем его из домена
    if [[ -z $user ]]; then
        if (( ! REMOVE )); then
            if (( SUBDOMAIN )); then
                splitSubdomain;
            else
                # Обработка доменного имени
                if [[ $OS == "centos" ]]; then
                    utime=$(date '+%s')
                    uhash=$(echo "${S_DOMAIN}$-${utime}" | md5sum)
                    readonly user=${S_DOMAIN}.${uhash:0:4}
                else
                    # Generation username from reversed domain name
                    # domain to array decomposition
                    typeset -a A_DOMAIN=() A_USER=()
                    mapfile -t A_DOMAIN < <( echo "$S_DOMAIN"|awk -F"." 'BEGIN { OFS=" " } { $1 = $1; print $0 }' )
                    # reverse (thnx to http://stackoverflow.com/questions/13360091/how-to-reverse-array-in-bash-onliner-for-loop)
                    for (( idx = ${#A_DOMAIN[@]}-1 ; idx >= 0 ; idx-- )); do
                        A_USER=( "${A_USER[@]}" "${A_DOMAIN[idx]}" )
                    done
                    # adding separators
                    readonly user=$(echo "${A_USER[@]}"|awk 'BEGIN { OFS="." } { $1 = $1; print $0 }')
                fi
            fi
        fi
    else
        readonly user
    fi

    if (( SUBDOMAIN )); then
        local WEBROOT_NEXT=""

        if [[ -n "$WEBROOT" ]]; then
            WEBROOT_NEXT="/$WEBROOT"
        fi

        WEBROOT=${siteroot}${WEBROOT_NEXT}
    else
        [[ -z $WEBROOT ]] && WEBROOT=www
    fi

    if (( ! REMOVE )); then
        CreateUser
        CreateSite
        AwstatsConfig
        Echo
    else
        RemoveAll
    fi

}

CreateUser() {

    CreateSubdir() {
        local FN=${FUNCNAME[0]}

        sudo -u "$user" mkdir -p "$BASEDIR/${user}/$siteroot"
    }

    local FN=${FUNCNAME[0]}

    if (( NOUSER )); then
        return
    fi

    # Проверка существования каталога сайта
    if [[ -d $BASEDIR/$user ]]; then
        if (( SUBDOMAIN )); then
            CreateSubdir
            return
        else
            writeLog "FATAL: User directory already exists. Aborting"
            false
        fi
    fi

    $ECHOMSG "Creating site user: " "$user"

    useradd "$user" -b $BASEDIR -m -U -s /bin/bash
    usermod -a -G "$user" $FRONTENDUSER

    if [[ -n $BACKENDUSER ]]; then
        usermod -a -G "$user" $BACKENDUSER
    fi
    # Chdir to user directory
    cd "${BASEDIR}/$user"

    # Создаём необходимые директории
    sudo -u "$user" mkdir -m 0700 .ssh
    sudo -u "$user" mkdir -p -m 0755 vault $WEBROOT
    sudo -u "$user" mkdir -m 0775 "${BASEDIR}/${user}/tmp" "${BASEDIR}/${user}/log"
    # и ключи
    sudo -u "$user" ssh-keygen -t $keytype -q -f "${BASEDIR}/${user}/.ssh/${user}_$keytype" -N ""
    sudo -u "$user" bash -c "cat ${BASEDIR}/${user}/.ssh/${user}_${keytype}.pub >> ${BASEDIR}/${user}/.ssh/authorized_keys"
    sudo -u "$user" chmod 0600 "${BASEDIR}/${user}/.ssh/authorized_keys"

    if (( COPY_SSH_KEY )); then
        mkdir -p /root/keys
        cat "${BASEDIR}/${user}/.ssh/${user}_$keytype" > "/root/keys/${hn}_${user}_$keytype"
    fi

    if (( SUBDOMAIN )); then
        CreateSubdir
    fi

    chmod 0750 "${BASEDIR}/$user"

    echoOK
}

CreateSite() {
    local FN=${FUNCNAME[0]}
    local -i F_PORT=0 FPM_CONFIG_EXISTS=0

    if (( NOSITE == 1 )); then
        return
    fi

    FpmPortFind() {
        local FN=${FUNCNAME[0]}
        local -a F_Ports=()
        
        if [[ $BACKEND =~ php-fpm|fpm ]]; then
            if [[ $SUBDOMAIN == 1 && -f "${fpm_d}/${user}.conf" ]]; then
                F_PORT=$(grep -E 'listen.*:[0-9]{4}' "${fpm_d}/${user}.conf" | grep -Eo '[0-9]{4}')
            else
                # Finding PHP-FPM instance port
                mapfile -t F_Ports < <( grep -hP 'listen.+:\d{4}' ${fpm_d}/*.conf | awk -F':' '{ print $2 }' | sort -n )

                if (( ! ${#F_Ports[@]} )); then
                    F_PORT=9001
                else
                    F_PORT=${F_Ports[0]}

                    for (( i=0; i<${#F_Ports[@]}; i++ )); do
                        if (( ${F_Ports[$i]} != F_PORT )); then
                            break
                        fi
                        (( F_PORT++ ))
                    done
                fi
            fi
        fi

    }

    CreateServerConfig() {
        local FN=${FUNCNAME[0]}
        local TEMPLATE=${1:-NOP}

        if [[ $TEMPLATE == "TEMPLATE_FPM" ]]; then
            local prefix=""
        else
            local prefix=${siteroot}${siteroot:+.}
        fi

        if [[ $OS == "debian" ]]; then
            local NEWCONFG=${prefix}${user}
        else
            local NEWCONFG=${prefix}${user}.conf
        fi

        if [[ -f "$NEWCONFG" ]]; then
            if [[ $TEMPLATE == "TEMPLATE_FPM" ]]; then
                FPM_CONFIG_EXISTS=1
                return 0
            else
                writeLog "FATAL: config file ${PWD}/$NEWCONFG already exists"
                false
            fi
        else
            sed -e "s|\\[BASEDIR\\]|${BASEDIR}|g" \
                -e "s|\\[USER\\]|${user}|g" \
                -e "s|\\[PORT\\]|${F_PORT}|g" \
                -e "s|\\[DOMAIN\\]|${S_DOMAIN}|g" \
                -e "s|\\[WEBROOT\\]|${WEBROOT}|g" \
                -e "s|\\[SUBDOMAIN\\]|${siteroot}${siteroot:+-}|g" \
                "$TEMPLATE" > "$NEWCONFG"

            if [[ $TEMPLATE =~ TEMPLATE_NG.* && $FPM_CONFIG_EXISTS == 1 ]]; then
                sed -i -e '/upstream fpm/,+3d' "$NEWCONFG"
            fi

            if [[ $OS == "centos" && $NOSELINUX == 0 ]]; then
                chcon -u system_u "$NEWCONFG"
                restorecon "$NEWCONFG"
            fi
        fi

    }

    DebianSiteEnable() {
        local FN=${FUNCNAME[0]}

        if [[ $OS == "debian" ]]; then
            cd ../sites-enabled
            ln -s "../sites-available/${user}" ./
        fi
    }

    if [[ $BACKEND =~ php-fpm|fpm ]]; then
        FpmPortFind
    fi

    # Backend configuration ===================================================
    if [[ $BACKEND =~ httpd|apache2 ]]; then
        $ECHOMSG "Creating backend configuration" "${BACKEND}: "
        BE=A2
        cd $httpd_sites
        CreateServerConfig TEMPLATE_A2
        DebianSiteEnable
    elif [[ $BACKEND =~ php-fpm|fpm ]]; then
        $ECHOMSG "Creating backend configuration" "${BACKEND}: "
        BE=FP
        cd $fpm_d
        CreateServerConfig TEMPLATE_FPM
    elif [[ $BACKEND =~ none ]]; then
        BE=NG
    fi

    echoOK

    # Frontend configuration ==================================================
    $ECHOMSG "Creating frontend configuration" "nginx: "
    # NginX website config creation
    cd $nginx_sites

    if (( SSL == 1 )); then
        CreateServerConfig TEMPLATE_NG_${BE}_SSL
    else
        CreateServerConfig TEMPLATE_NG_$BE
    fi

    DebianSiteEnable

    warn=1
    if [[ "$BACKEND" == "none" ]]; then
        echo -e 'Site content is missing' >> "${BASEDIR}/${user}/$WEBROOT/index.html"
    else
        # shellcheck disable=SC2016
        echo -e '<?php\necho("PHP: Site content for domain " . $_SERVER["HTTP_HOST"] . " is missing");\n?>' >> "${BASEDIR}/${user}/$WEBROOT/index.php"
    fi
    warn=0

    cd "$HOME"
    echoOK

    Reloading
}

AwstatsConfig() {
    local FN=${FUNCNAME[0]}

    if (( NOAWSTATS == 1 )); then
        return
    fi

    [[ -z $user ]] && findUserName

    $ECHOMSG "Creating awstats configuration: "
    cp /etc/awstats/awstats.TEMPLATE /etc/awstats/awstats.${S_DOMAIN}.conf

    sed -i -r -e "s|\\[BASEDIR\\]|${BASEDIR}|g" \
        -e "s|\\[DOMAIN\\]|${S_DOMAIN}|g" \
        -e "s|\\[SUBDOMAIN\\]|${siteroot}${siteroot:+-}|g" \
        -e "s|\\[USER\\]|${user}|g" \
        /etc/awstats/awstats.${S_DOMAIN}.conf
    # shellcheck disable=SC2174
    mkdir -p -m 755 /var/lib/awstats/${S_DOMAIN}
    chown root:root /var/lib/awstats/${S_DOMAIN}    # Нахуя??
    restorecon -R /etc/awstats /var/lib/awstats

    echoOK
}

Reloading() {
    local FN=${FUNCNAME[0]}

    if (( ! NOSELINUX )); then
        restorecon -R "${BASEDIR}/${user}"
    fi

    if (( ! NORELOAD )); then
        $ECHOMSG "Reloading web-servers: "

        if [[ $OS == "debian" ]]; then
            service apache2 reload
            service nginx configtest
            service nginx reload
        else

            if [[ $BACKEND =~ httpd|apache2 ]]; then
                apachectl configtest
            elif [[ $BACKEND =~ php-fpm|fpm ]]; then
                /sbin/php-fpm -t
            fi

            nginx -qt

            if [[ $BACKEND =~ httpd|apache2 ]]; then
                systemctl reload httpd.service
            elif [[ $BACKEND =~ php-fpm|fpm ]]; then
                systemctl reload php-fpm.service
            fi

            systemctl reload nginx.service
        fi

        echoOK

    fi

    if (( ! NOSELINUX )); then
        restorecon -R "${BASEDIR}/${user}"
    fi
}

Echo() {
    local FN=${FUNCNAME[0]}

    if (( NOECHO )); then
        return
    fi

    echo "
#####
# Wiki page:
#
===============================================================================
"

if (( WEBINFO )); then
    echo "
h3. Web

*URI:* http://$ipaddr
*Frontend:* @$(nginx -V 2>&1 | awk '/nginx version:/ { print $3 }')@"
    if [[ $BACKEND =~ httpd|apache2 ]]; then
        echo "*Backend:* @$(httpd -V | awk '/Server version:/ { print $3 }') + $(php -v | awk '/PHP .* \(cli\)/ { print $1, $2 }')@"
    elif [[ $BACKEND =~ php-fpm|fpm ]]; then
        echo "*Backend:* @PHP-FPM $(php -v | awk '/PHP .* \(cli\)/ { print $2 }')@"
    fi
fi

echo "
h3. SSH Access

*Host:* @${hn}@
*User:* @${user}@
*Private Key:* {{collapse
<pre>
$(cat "$BASEDIR/${user}/.ssh/${user}_$keytype")
</pre>
}}

===============================================================================
#"

}

splitSubdomain() {
    # Разбивает доменное имя (длинное, при включённой опции SUBDOMAIN) на имя 
    # пользователя (sld.tld) и имя каталога - корня сайта $siteroot

    local FN=${FUNCNAME[0]}

    readonly user=$(echo "$S_DOMAIN" | grep -Eo '[a-z0-9]+\.[a-z]+$')
    readonly siteroot=${S_DOMAIN%\.*\.*}

    if [[ "$user" == "$siteroot" ]]; then
        echo "FATAL: Wrong input data after '-d' (maybe '-s' was unnecessary?)"
        false
    fi
}

findUserName() {
    local FN=${FUNCNAME[0]}

    local -i domain_users_count=0
    
    if [[ $OS == "centos" ]]; then
        # Кол-во пользователей вида ${S_DOMAIN}.????
        domain_users_count=$(grep -Pc "^${S_DOMAIN}" /etc/passwd)
        if (( domain_users_count > 1 )); then
            writeLog "More than one matching user detected. Please resolve collision manually. Aborting"
            false
        elif (( domain_users_count == 0 )); then
            writeLog "No matching user detected. Aborting"
            false
        else
            readonly user=$(grep -P "^${S_DOMAIN}" /etc/passwd | awk -F":" '{ print $1 };')
        fi
    else
        echo "Not implemented" >&2
        false
    fi

}

RemoveAll() {
    local FN=${FUNCNAME[0]}
    local frontend_config="" backend_config=""
    local -r timestamp=$(date '+%FT%H%M')

    local bakdir="/root/removed_configs"

    mkdir -p $bakdir

    if (( SUBDOMAIN )); then
        splitSubdomain
    else
        if [[ -z $user ]]; then
            findUserName
        fi

        if [[ -z $user ]]; then
            echo "FATAL: username is empty" >&2
            false
        fi
    fi

    warn=1

    if (( ! SUBDOMAIN ));then
        # Removing user
        $ECHOMSG "Removing site user" "${user}: "
        userdel "$user" 2>/dev/null
        rm "/var/spool/mail/$user"
        echoOK
        # Removing group
        $ECHOMSG "Removing group" "${user}: "
        groupdel "$user"
        echoOK
        # Removing crontab
        if [[ -f "/var/spool/cron/$user" ]]; then
            $ECHOMSG "Removing crontab" "${user}: "
            mv "/var/spool/cron/$user" "${bakdir}/${user}-crontab.${timestamp}.bak"
        fi
        echoOK
    fi

    # Removing site configs
    $ECHOMSG "Removing site configs" "${siteroot:-$user}: "

    # Removing awstats config and stats
    if (( NOAWSTATS == 0 )); then
        [[ -f "/etc/awstats/awstats.${S_DOMAIN}.conf" ]] && rm "/etc/awstats/awstats.${S_DOMAIN}.conf"
        [[ -d "/var/lib/awstats/${S_DOMAIN}" ]] && rm -r "/var/lib/awstats/${S_DOMAIN}"
    fi

    if [[ $OS == "debian" ]]; then
        rm "/etc/nginx/sites-enabled/${siteroot}${siteroot:+.}$user"
        rm "/etc/apache2/sites-enabled/${siteroot}${siteroot:+.}$user"
        frontend_config=${nginx_sites}/${siteroot}${siteroot:+.}$user
        backend_config=${httpd_sites}/${siteroot}${siteroot:+.}$user
    else
        frontend_config=${nginx_sites}/${siteroot}${siteroot:+.}${user}.conf

        if (( ! SUBDOMAIN )); then
            if [[ $BACKEND =~ httpd|apache2 ]]; then
                backend_config=${httpd_sites}/${siteroot}${siteroot:+.}${user}.conf
            elif [[ $BACKEND =~ php-fpm|fpm ]]; then
                backend_config=${fpm_d}/${siteroot}${siteroot:+.}${user}.conf
            fi
        fi
    fi

    mv "$frontend_config" "${bakdir}/${frontend_config##*\/}-frontend.${timestamp}.bak"
    [[ -n "$backend_config" ]] && mv "$backend_config" "${bakdir}/${backend_config##*\/}-backend.${timestamp}.bak"

    flushThisShit() {
        local FN=${FUNCNAME[0]}
        local arg1="$1"
        local REPLY=""

        echo -e "\\n"

        while true; do
            read -r -p ":: Are you really wanna remove directory \"${arg1}\"? [y/N] " REPLY

            if [[ $REPLY =~ ^[Yy] ]]; then
                rm -rf "$arg1"
                break
            elif [[ $REPLY =~ ^[Nn] || -z "$REPLY" ]]; then
                echo "Cancelled." >&2
                REMOVEALL=0
                break
            else
                echo ":: Please answer 'yes' or 'no'" >&2
            fi
        done
    }

    if (( REMOVEALL )); then
        if (( SUBDOMAIN )); then
            flushThisShit "${BASEDIR}/${user}/$siteroot"
        else
            flushThisShit "${BASEDIR}/$user"
        fi
    fi

    warn=0
    echoOK

    Reloading

    if (( ! REMOVEALL )); then
        echo -e "\\e[0;37m[\\e[0;33mSite directory was not removed!\\e[0;37m]\\e[0m"
    fi

}

if [[ -f /etc/init.d/functions ]]; then
    . /etc/init.d/functions
    ECHO_SUCCESS=echo_success
    ECHO_FAILURE=echo_failure
    ECHO_WARNING=echo_warning
elif [[ -f /lib/lsb/init-functions ]]; then
    . /lib/lsb/init-functions
    ECHO_SUCCESS="log_end_msg 0"
    ECHO_FAILURE="log_end_msg 1"
    ECHO_WARNING="log_end_msg 255"
else
    echo "FATAL: init-functions not found"
    exit 18
fi

set -o nounset

except() {
    RET=$?

    if (( warn )); then
        $ECHO_WARNING
        [[ $OS == "centos" ]] && echo
        return
    else
        echo "Runtime error in function ${FN:-UNKNOWN}"
        $ECHO_FAILURE
        [[ $OS == "centos" ]] && echo
        exit $RET
    fi
}

echoOK() {

    if (( warn )); then
        echo
        return
    else
        $ECHO_SUCCESS
        [[ $OS == "centos" ]] && echo
    fi
}

writeLog() {
    echo -e "\\n$*" 1>&2
    logger -t "$bn" "$*"
}

usage() {
    echo -e "Usage: $bn <option(s)>
        Options:
        -a          configure Awstats for existing domain and exit
        -b <>       backend (httpd|apache2, php-fpm|fpm or none) (REQUIRED)
        -d <>       site domain (REQUIRED)
        -i <>       IP address (default: \$domain)
        -l          create Nginx config with SSL
        -r <>       web root directory (default: www)
        -s          create subdomain for existing user
        -u <>       site user
        -x          remove user and website configs instead creation
        -A          do not configure Awstats
        -B          BASEDIR (default: /var/www)
        -C          copy SSH private key in /root/keys/<hostname>_<username>_$keytype
        -E          suppress Wiki page print
        -L          do not execute SELinux-related statements
        -N          do not reload web-servers
        -S          skip website config creation
        -U          skip user creation
        -W          print frontend/backend info for Wiki
        -X          remove user, website configs AND FILES
        "
}

while getopts "ab:d:u:i:r:slxhAB:CELNSUWX" OPTION; do
    case $OPTION in
        a) AWSTATSONLY=1
            ;;
        b) BACKEND=$OPTARG
            ;;
        d) S_DOMAIN=$OPTARG
            ;;
        r) WEBROOT=$OPTARG
            ;;
        s) SUBDOMAIN=1
            ;;
        u) user=$OPTARG
            ;;
        i) S_IPADDR=$OPTARG
            ;;
        l) SSL=1
            ;;
        x) REMOVE=1
            ;;
        A) NOAWSTATS=1
            ;;
        B) BASEDIR=$OPTARG
            ;;
        C) COPY_SSH_KEY=1;
            ;;
        E) NOECHO=1
            ;;
        L) NOSELINUX=1
            ;;
        N) NORELOAD=1
            ;;
        S) NOSITE=1
            ;;
        U) NOUSER=1
            ;;
        W) WEBINFO=1
            ;;
        X) REMOVE=1; REMOVEALL=1
            ;;
        h) usage
            exit 0
                ;;
        *) usage
            exit 1
    esac
done

if [[ ${1:-NOP} == "NOP" ]]; then
    usage
    exit 1
fi

Main
