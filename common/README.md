# common
Роль для первичной настройки хоста на CentOS 6|7 (for WM LLC)

## Variables
```yaml
alien: bool # default: true :Указывает на то, что хост не принадлежит к сети организации

selinux_state: bool # default: "enforcing"

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

common_icinga2_enable: bool # default: true :Регистрировать ли хост в мониторинге
common_icinga2_master: "host" # default: none :Хост кластера icinga2, на каотором хранится конфигурация зон
common_icinga2_master_zone: "string" # default: none :Мастер-зона icinga2
common_icinga2_master_zone_net_list: # default: none :Сети для автоопределения занесения хоста в мастер-зону
  - "ipv4/prefix"
common_icinga2_satellite_zone: "string" # default: none :Сателлит-зона icinga2
common_icinga2_satellite_zone_net_list: # default: none :Сети для автоопределения занесения хоста в сателлит-зону
  - "ipv4/prefix"

common_icinga2_conf:
  host_main_template: "string" # default: "centos-host" :Основной шаблон хоста (первый import)
  host_templates: [ 'string', ... ] # default: none :Дополнительные шаблоны
  ip_address: "ipv4" # default: autodetect
  display_name: "string" # default: ansible_hostname
  int_name: "string" # default: autodetect :Шаблон имени сетевых интерфейсов (eth, ens, eno, ...)

common_icinga2_freeform: # default:none :Любая конфигурация
  - "string [string ...]"
```

## Tags
`colorize` `console` `domain` `hostname` `icinga2` `ifcfg` `ipset` `iptables` `journald` `kvm` `logrotate` `mail` `ntp` `packages` `porntube` `rsyslog` `services` `snmp` `sudo` `tuned` `update` `vmware` `xt_recent`

