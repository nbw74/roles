postgresql-wal-archive
======================
## Описание
+ Устанавливает указанные версии postgresql;
+ создаёт юзерей basebackup и walarchive;
+ помещает в систему скрипты для бэкапа и очистки WAL;
  + создаёт записи крона для обоих скриптов
## Переменные
```yaml
pwa_add_packages: [] # additional packages (e.g. postgresql modules)
pwa_allow_rootfs: bool # Default: false; allow keep backups in root fs

pwa_basebackup_cron:
  - name: "string" # MANDATORY; cron task name
    minute: "string" # Default: "20"; minute when the job should run ( 0-59, *, */2, etc )
    hour: "string" # Default: "4"; hour when the job should run ( 0-23, *, */2, etc )
    day: "string" # Default: "*/3"; day of the month the job should run ( 1-31, *, */2, etc )
    weekday: "string" # Default: "*"; day of the week that the job should run ( 0-6 for Sunday-Saturday, *, etc )
    month: "string" # Default: "*"; month of the year the job should run ( 1-12, *, */2, etc )
    disabled: bool # Default: no; if the job should be disabled (commented out) in the crontab
    job:
      addr:
        - <ip_or_fqdn> # MANDATORY; PostgreSQL instance address for backup
      depth: int # default: 3; number of full backups stored
      strip_last_dash: bool # Default: false

pwa_basebackup_home: string # default: '/srv/{{ pwa_basebackup_user }}'
pwa_basebackup_user: string # default: 'basebackup'

pwa_pgpass_entries:
  - host: <ip_or_fqdn> # MANDATORY
    port: int # default: '*'
    user: string # default: 'replicator'
    password: string # MANDATORY

pwa_postgresql_versions: [] # MANDATORY

pwa_server_roles:
  - basebackup
  - walarchive

pwa_walarchive_home: string # default: '/srv/{{ pwa_walarchive_user }}'
pwa_walarchive_user: string # default: walarchive

pwa_walarchive_cron:
  minute: "string" # Default: "*/19"; minute when the job should run ( 0-59, *, */2, etc )
  disabled: bool # Default: no; if the job should be disabled (commented out) in the crontab
  job:
    min_age: int # Default: 12; alert if oldest WAL archive age less than <int> days
    rm_count: int # Default: 100; number of WAL archives for one pass remove
    max_used: int # Default: 86; start remove oldest WALs if disk usage more than <int>%

pwa_walarchive_keys: # public keys of postgres user from WAL sources
  - type: <ssh_key_type> # Default: ed25519
    data: <ssh_key_data>
    comment: <ssh_key_comment>

```
