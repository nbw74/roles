# common
Роль для первичной настройки хоста на CentOS 6|7 (for WM LLC)

## Variables
```yaml
alien: bool # default: true :Указывает на то, что хост не принадлежит к сети организации

common_add_packages: []

common_aliases_root: "string" # Почтовый адрес для пересылки почты суперпользователя

common_cron_user_tasks:
  - user: "string" # mandatory; the specific user whose crontab should be modified
    name: "string" # mandatory; description of a crontab entry
    minute: "string" # default: *; minute when the job should run ( 0-59, *, */2, etc )
    hour: "string" # default: *; hour when the job should run ( 0-23, *, */2, etc )
    day: "string" # default: *; day of the month the job should run ( 1-31, *, */2, etc )
    weekday: "string" # default: *; day of the week that the job should run ( 0-6 for Sunday-Saturday, *, etc )
    month: "string" # default: *; month of the year the job should run ( 1-12, *, */2, etc )
    job: "string" # mandatory; the command to execute
    disabled: bool # default: no; if the job should be disabled (commented out) in the crontab
    state: bool # default: yes; whether to ensure the job is present or absent

common_etc_hosts:
  <hostname>: <ipaddr>

common_fstrim_weekly: # Cron job for weekly fstrim launch
  - "string" # list of trimmed filesystems

common_icinga2_conf:
  host_main_template: "string" # default: "centos-host" :Основной шаблон хоста (первый import)
  host_templates: [ 'string', ... ] # default: none :Дополнительные шаблоны
  ip_address: "ipv4" # default: autodetect
  display_name: "string" # default: ansible_hostname
  int_name: "string" # default: autodetect :Шаблон имени сетевых интерфейсов (eth, ens, eno, ...)
  vars:
    key: value
  freeform: |
    any block

common_icinga2_enable: bool # default: true :Регистрировать ли хост в мониторинге

common_icinga2_master: "host" # default: none :Хост кластера icinga2, на каотором хранится конфигурация зон
common_icinga2_master_zone: "string" # default: none :Мастер-зона icinga2

common_icinga2_master_zone_net_list: # default: none :Сети для автоопределения занесения хоста в мастер-зону
  - "ipv4/prefix"

common_icinga2_satellite_zone: "string" # default: none :Сателлит-зона icinga2

common_icinga2_satellite_zone_net_list: # default: none :Сети для автоопределения занесения хоста в сателлит-зону
  - "ipv4/prefix"

## IFCFG
# common_ifcfg: - переписывает файл конфига ЦЕЛИКОМ
# common_ifcfg_vars: - добавляет или удаляет строчки из файла конфига
# Использовать как взаимоисключающие.

common_ifcfg: # (default: []) шаблонизация файлов /etc/sysconfig/network-scripts/ifcfg-<dev>
  - dev: device_name
    state: bool # (default: true) При false удаляет конфиг интерфейса
    variables:
      KEY: "value"  # KEY="value"

common_ifcfg_restart: bool # (default: true) перезапуск интефейса после изменения common_ifcfg

common_ifcfg_vars: # (default: []) добавление переменных в /etc/sysconfig/network-scripts/ifcfg-<dev>
  - dev: device_name
    variables:
      KEY: "value"  # KEY="value"
# чтобы удалить переменную, присвойте ей значение 'no' или 'false' без кавычек.

common_ipa_principal: string # Mandatory if not alien
common_ipa_password: string # Mandatory if not alien

common_journal_gateway_enable: bool # default: false

common_leave_networkmanager: bool # default: false

common_mounts:
  - path: string  # Required; path to the mount point (e.g. /mnt/files)
    src: string  # Device to be mounted on path. Required when state set to present or mounted.
    fstype: string  # Filesystem type. Required when state is present or mounted.
    opts: string  # Mount options (see fstab(5))
    state: string  # absent, mounted, present or unmounted. Default is 'mounted'. See details in the ansible docs.

common_ntp_domains: # Хэш с локальными доменами и обслуживающими их NTP-серверами
  - domain: "fqdn"
    servers: [ 'string', 'string', ... ]

common_ntp_servers: []
common_ntp_pool: ru

common_resolv_conf:
  domain: string
  search: []
  nameservers: []

common_rsyslog_collector: "string" # Хостнейм коллектора логов (rsyslog)

common_selinux_alert_recipients: "string" # Почтовый адрес для отсылки уведомлений SELinux
common_sha_store_addr: "fqdn|ipv4" # Адрес сервера для скрипта проверки системных файлов
common_sha_store_user: "string" # Имя пользователя для скрипта проверки системных файлов

common_sudoers_d:
  - name: filename
    lines:
      - user: username
        special: string # default: 'ALL=(ALL) NOPASSWD:'
        command: /full/path/command [params]
    state: bool # default: true

common_snmp_secname: "string" # Security name for snmpd.conf
common_snmp_community: "string" # Community for snmpd.conf
common_snmp_syslocation: "string" # default: "Earth" :System location for snmpd.conf
common_snmp_syscontact: "string" # System contact for snmpd.conf
common_snmpd_conf_line: [] # Freeform lines

common_ssh_direct_list: # Список адресов, с которых можно открывать неограниченное
  - "ipv4"              # кол-во соединений к SSHd в единицу времени

common_static_route: # Добавить статичные маршруты в /etc/sysconfig/network-scripts/route-<dev>,
  - dev: "device_name" # ...а также "на лету" в таблицу маршрутизации (или удалить их)
    routes:
      - { dest: "CIDR", gw: "ipv4_address"[, state: bool] }
      - ...

selinux_custom_booleans:
  - { name: 'boolean_name'[, state: 'bool'] }

common_sysctl_vars:
  key: value

selinux_state: bool # default: "enforcing"

timezone: "string" # default: "Europe/Moscow"
```

## Tags
`colorize` `console` `cron` `domain` `etckeeper` `hostname` `icinga2` `ifcfg` `ipset` `iptables` `journald` `kvm` `logrotate` `mail` `ntp` `packages` `porntube` `rsyslog` `services` `snmp` `sudo` `tuned` `update` `vmware` `xt_recent`

