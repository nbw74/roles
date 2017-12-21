# common
Роль для первичной настройки хоста на CentOS 6|7 (for WM LLC)

## Variables
```yaml
alien: bool # default: true :Указывает на то, что хост не принадлежит к сети организации

common_aliases_root: "string" # Почтовый адрес для пересылки почты суперпользователя
common_selinux_alert_recipients: "string" # Почтовый адрес для отсылки уведомлений SELinux

common_ntp_servers_list: "string|string|..." # Список локальных/кастомных NTP-серверов
common_ntp_domains: # Хэш с локальными доменами и обслуживающими их NTP-серверами
  - domain: "fqdn"
    servers: [ 'string', 'string', ... ]

common_rsyslog_collector: "string" # Хостнейм коллектора логов (rsyslog)
common_sha_store_addr: "fqdn|ipv4" # Адрес сервера для скрипта проверки системных файлов
common_sha_store_user: "string" # Имя пользователя для скрипта проверки системных файлов

common_snmp_secname: "string" # Security name for snmpd.conf
common_snmp_community: "string" # Community for snmpd.conf
common_snmp_syslocation: "string" # default: "Earth" :System location for snmpd.conf
common_snmp_syscontact: "string" # System contact for snmpd.conf

common_ssh_direct_list: # Список адресов, с которых можно открывать неограниченное
  - "ipv4"              # кол-во соединений к SSHd в единицу времени
```

## Tags
`colorize` `console` `domain` `hostname` `ifcfg` `ipset` `iptables` `journald` `kvm` `logrotate` `mail` `ntp` `packages` `porntube` `rsyslog` `services` `snmpd` `sudo` `tuned` `update` `vmware` `xt_recent`

