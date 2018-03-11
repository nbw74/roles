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
typeset -i COPY_SSH_KEY=0 SUBDOMAIN=0 warn=0 MOBILE=0 GO_SSL=0
typeset BACKEND="" FRONTENDUSER="" BACKENDUSER="" S_DOMAIN="" user="" WEBROOT=""
typeset BASEDIR=/var/www user="" siteroot="" _alt=""
# For envsubst templates
readonly root_path="root_path"
readonly request_uri="request_uri"
readonly fpmport="fpmport"
readonly pool="pool"

export BASEDIR user S_DOMAIN WEBROOT siteroot _alt root_path request_uri fpmport pool

Main() {
    local FN=${FUNCNAME[0]}
    local utime="" uhash=""

    trap except ERR

    if [[ -z $S_DOMAIN ]]; then
        writeLog "FATAL: Required parameter is missing (-s)"
        false
    fi

    if [[ -f /etc/redhat-release ]]; then
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
        echo "FATAL: Unknown operating system (only RHEL-based is supported)" >&2
        false
    fi

    if (( AWSTATSONLY )); then
        AwstatsConfig
        exit 0
    fi

    if (( GO_SSL )); then
        goSSL
        exit 0
    fi

    if [[ -z $BACKEND ]]; then
        writeLog "FATAL: Required parameter is missing (-b)"
        false
    else
        if ! [[ $BACKEND =~ httpd|apache2|php-fpm|fpm|none ]]; then
            writeLog "FATAL: Unknown backend (${BACKEND})"
            false
        fi
    fi

    # Проверка существования домена
    if grep -RPq "\\s+${S_DOMAIN}[; ]" $nginx_sites
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
                utime=$(date '+%s')
                uhash=$(echo "${S_DOMAIN}$-${utime}" | md5sum)
                readonly user=${S_DOMAIN}.${uhash:0:4}
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

goSSL() {
    FN=${FUNCNAME[0]}
    local conf_file="" root=""
    local -i F_PORT=0 FPM_CONFIG_EXISTS=0
    export F_PORT
    # Find username from Nginx configuration
    conf_file=$(grep -rlP "server_name\\s+${S_DOMAIN}" /etc/nginx/conf.d | head -n1)

    if [[ ! -f $conf_file ]]; then
        writeLog "FATAL: domain not found in then Nginx configuration"
        false
    fi

    user=$(basename -s .conf "$conf_file")
    # Find root_path
    root=$(awk '/set[[:space:]]+\$root_path/ { gsub(/'\''/, ""); sub(/;/, ""); print $3 }' "$conf_file")

    if [[ -z $root ]]; then
        writeLog "FATAL: root_path not found in '$conf_file'"
        false
    fi
    # Find BASEDIR
    BASEDIR=${root%%$user*}; BASEDIR=${BASEDIR%\/}
    # Find WEBROOT
    WEBROOT=${root##*$user}; WEBROOT=${WEBROOT#\/}
    # Find F_PORT
    F_PORT=$(awk '/upstream/ { match($0, /[0-9]+/); print substr( $0, RSTART, RLENGTH ); exit }' $conf_file)
    # Find if mobile
    if grep -Pq '\sm\.[a-z0-9]' "$conf_file"
    then
        MOBILE=1
    fi
    # Find if alternative ip included
    if grep -Fq '_alt.conf' "$conf_file"
    then
        _alt="_alt"
    fi
    # Set template type
    if (( F_PORT )); then
        BE=FP
    else
        BE=A2
    fi

    # This variables used in function CreateNginxConfig
    local newconfg=$conf_file
    local template=TEMPLATE_NG_${BE}_SSL

    cd $nginx_sites || false
    cp -a "$conf_file" "${conf_file}.$(date '+%s').bak"
    envsubst < "$template" > "$newconfg"
    CreateNginxConfig
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

    useradd "$user" -b "$BASEDIR" -m -U -s /bin/bash
    usermod -a -G "$user" $FRONTENDUSER

    if [[ -n $BACKENDUSER ]]; then
        usermod -a -G "$user" $BACKENDUSER
    fi
    # Chdir to user directory
    cd "${BASEDIR}/$user" || false

    # Создаём необходимые директории
    sudo -u "$user" mkdir -m 0700 .ssh
    sudo -u "$user" mkdir -p -m 0755 vault "$WEBROOT"
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

CreateNginxConfig() {
    local FN=${FUNCNAME[0]}
    local upstream=""
    upstream=$(mktemp --tmpdir "${bn%\.*}.upstream.XXXX")

    if (( F_PORT )); then
        envsubst < "TEMPLATE_UPSTREAM" > "$upstream"
        ed -s "$newconfg" <<IN
/server[[:space:]]\\+{/-r $upstream
w
q
IN
    fi

    # shellcheck disable=SC2030
    if (( MOBILE )); then
        local S_DOMAIN_tmp=$S_DOMAIN
        S_DOMAIN="m.$S_DOMAIN"
        echo -e "\\n## MOBILE VERSION ##\\n" >> "$newconfg"
        envsubst < "$template" >> "$newconfg"
        S_DOMAIN=$S_DOMAIN_tmp
    fi
    # What the Fuck??
    if (( FPM_CONFIG_EXISTS )); then
        sed -i -e '/upstream fpm/,+3d' "$newconfg"
    fi

    if [[ -f "$upstream" ]]; then
        rm "$upstream"
    fi
}

CreateSite() {
    local FN=${FUNCNAME[0]}
    local -i F_PORT=0 FPM_CONFIG_EXISTS=0

    export F_PORT

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
        local template=${1:-NOP}

        if [[ $template == "TEMPLATE_FPM" ]]; then
            local prefix=""
        else
            local prefix=${siteroot}${siteroot:+.}
        fi

        local newconfg=${prefix}${user}.conf

        if [[ -f "$newconfg" ]]; then
            if [[ $template == "TEMPLATE_FPM" ]]; then
                FPM_CONFIG_EXISTS=1
                return 0
            else
                writeLog "FATAL: config file ${PWD}/$newconfg already exists"
                false
            fi
        else
            local SITEROOT="${siteroot}${siteroot:+-}"
            export SITEROOT
            envsubst < "$template" > "$newconfg"

            if [[ $template =~ TEMPLATE_NG.* ]]; then
                CreateNginxConfig
            fi

            if (( ! NOSELINUX )); then
                chcon -u system_u "$newconfg"
                restorecon "$newconfg"
            fi
        fi

    }

    if [[ $BACKEND =~ php-fpm|fpm ]]; then
        FpmPortFind
    fi

    # Backend configuration ===================================================
    if [[ $BACKEND =~ httpd|apache2 ]]; then
        $ECHOMSG "Creating backend configuration" "${BACKEND}: "
        BE=A2
        cd $httpd_sites || false
        CreateServerConfig TEMPLATE_A2
    elif [[ $BACKEND =~ php-fpm|fpm ]]; then
        $ECHOMSG "Creating backend configuration" "${BACKEND}: "
        BE=FP
        cd $fpm_d || false
        CreateServerConfig TEMPLATE_FPM
    elif [[ $BACKEND =~ none ]]; then
        BE=NG
    fi

    echoOK

    # Frontend configuration ==================================================
    $ECHOMSG "Creating frontend configuration" "nginx: "
    # NginX website config creation
    cd $nginx_sites || false

    if (( SSL == 1 )); then
        CreateServerConfig TEMPLATE_NG_${BE}_SSL
    else
        CreateServerConfig TEMPLATE_NG_$BE
    fi

    warn=1
    if [[ "$BACKEND" == "none" ]]; then
        echo -e 'Site content is missing' >> "${BASEDIR}/${user}/$WEBROOT/index.html"
    else
        # shellcheck disable=SC2016
        echo -e '<?php\necho("PHP: Site content for domain " . $_SERVER["HTTP_HOST"] . " is missing");\n?>' >> "${BASEDIR}/${user}/$WEBROOT/index.php"
    fi
    warn=0

    cd "$HOME" || false
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
    # shellcheck disable=SC2034
    local SITEROOT="${siteroot}${siteroot:+-}"
    envsubst < "/etc/awstats/awstats.TEMPLATE" > "/etc/awstats/awstats.${S_DOMAIN}.conf"
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

*URI:* http://${S_DOMAIN}"
if (( MOBILE )); then
    echo "*URI (mob):* http://m.${S_DOMAIN}"
fi
echo "*Frontend:* @$(nginx -V 2>&1 | awk '/nginx version:/ { print $3 }')@"
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
    if (( ! NOAWSTATS )); then
        [[ -f "/etc/awstats/awstats.${S_DOMAIN}.conf" ]] && rm "/etc/awstats/awstats.${S_DOMAIN}.conf"
        [[ -d "/var/lib/awstats/${S_DOMAIN}" ]] && rm -r "/var/lib/awstats/${S_DOMAIN}"
    fi

    frontend_config="${nginx_sites}/${siteroot}${siteroot:+.}${user}.conf"

    if (( ! SUBDOMAIN )); then
        if [[ $BACKEND =~ httpd|apache2 ]]; then
            backend_config="${httpd_sites}/${siteroot}${siteroot:+.}${user}.conf"
        elif [[ $BACKEND =~ php-fpm|fpm ]]; then
            backend_config="${fpm_d}/${siteroot}${siteroot:+.}${user}.conf"
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

# shellcheck disable=SC1091
if [[ -f /etc/init.d/functions ]]; then
    . /etc/init.d/functions
    ECHO_SUCCESS=echo_success
    ECHO_FAILURE=echo_failure
    ECHO_WARNING=echo_warning
else
    echo "FATAL: init-functions not found"
    exit 18
fi

set -o nounset

except() {
    RET=$?

    if (( warn )); then
        $ECHO_WARNING
        echo
        return
    else
        echo "Runtime error in function ${FN:-UNKNOWN}"
        $ECHO_FAILURE
        echo
        exit $RET
    fi
}

echoOK() {

    if (( warn )); then
        echo
        return
    else
        $ECHO_SUCCESS
        echo
    fi
}

writeLog() {
    echo -e "\\n$*" 1>&2
    logger -t "$bn" "$*"
}

usage() {
    echo -e "Usage: $bn <option(s)>
        Options:
        -a, --awstatsonly           configure Awstats for existing domain and exit
        --alt                       use alternative Nginx listen IP
        -b, --backend <httpd|apache2|php-fpm|fpm|none>      backend (REQUIRED)
        -d, --domain <string>       site domain (REQUIRED)
        -i, --address <ipv4|string> IP address or hostname (default: \$domain)
        -l, --ssl                   create Nginx config with SSL
        --go-ssl                    convert configuration to SSL
        -m, --mobile                also add Nginx configuration for mobile domain
        -r, --root <string>         web root directory (default: www)
        -s, --subdomain             create subdomain for existing user
        -u, --user <string>         site user
        -x, --remove                remove user and website configs instead creation
        -A, --noawstats             skip Awstats configuring
        -B, --basedir <string>      BASEDIR (default: /var/www)
        -C, --copy-ssh-key          copy SSH private key in /root/keys/<hostname>_<username>_$keytype
        -E, --noecho                suppress Wiki page print
        -L, --noselinux             do not execute SELinux-related statements
        -N, --noreload              do not reload web-servers
        -S, --nosite                skip website config creation
        -U, --nouser                skip user creation
        -W, --webinfo               print frontend/backend info for Wiki
        -X, --removeall             remove user, website configs AND FILES
"
}

if ! TEMP=$(getopt -o ab:d:u:i:r:slmxhAB:CELNSUWX --longoptions alt,\
awstatsonly,backend:,domain:,root:,subdomain,user:,address:,ssl,remove,\
noawstats,basedir:,copy-ssh-key,noecho,noreload,nosite,nouser,webinfo,\
removeall,help,mobile,go-ssl -n "$bn" -- "$@")
then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case $1 in
        -a|--awstatsonly)   AWSTATSONLY=1 ; shift   ;;
        --alt)              _alt="_alt" ;   shift   ;;
        -b|--backend)       BACKEND=$2 ;    shift 2 ;;
        -d|--domain)        S_DOMAIN=$2 ;   shift 2 ;;
        -r|--root)          WEBROOT=$2 ;    shift 2 ;;
        -s|--subdomain)     SUBDOMAIN=1 ;   shift   ;;
        -u|--user)          user=$2 ;       shift 2 ;;
        -i|--address)       S_IPADDR=$2 ;   shift 2 ;;
        -l|--ssl)           SSL=1 ;         shift   ;;
        --go-ssl)           GO_SSL=1 ;      shift   ;;
        -m|--mobile)        MOBILE=1 ;      shift   ;;
        -x|--remove)        REMOVE=1 ;      shift   ;;
        -A|--noawstats)     NOAWSTATS=1 ;   shift   ;;
        -B|--basedir)       BASEDIR=$2 ;    shift 2 ;;
        -C|--copy-ssh-key)  COPY_SSH_KEY=1 ; shift  ;;
        -E|--noecho)        NOECHO=1 ;      shift   ;;
        -L|--noselinux)     NOSELINUX=1 ;   shift   ;;
        -N|--noreload)      NORELOAD=1 ;    shift   ;;
        -S|--nosite)        NOSITE=1 ;      shift   ;;
        -U|--nouser)        NOUSER=1 ;      shift   ;;
        -W|--webinfo)       WEBINFO=1 ;     shift   ;;
        -X|--removeall)     REMOVE=1; REMOVEALL=1 ; shift ;;
        -h|--help)          usage ;         exit 0  ;;
        --)                 shift ;         break   ;;
        *)                  usage ;         exit 1
    esac
done

Main
