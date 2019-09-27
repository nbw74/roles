postgresql
==========

Роль для развёртывания СУБД PostgreSQL.

## Описание переменных для host_vars:

```yaml
postgresql_additional_packages: # Дополнительно установить указанные пакеты
  - "package1"

postgresql_conf: # Параметры конфигурации СУБД
    listen_addresses: "ipaddr,ipaddr" # default: * (change requires restart)
    port: int # default: 5432 (change requires restart)
    max_connections: int # default: 100 (change requires restart)
    shared_buffers: intUNIT # default: 20% from total RAM (change requires restart)
    temp_buffers: intUNIT # default: 8MB
    work_mem: intUNIT # default: 1% from total RAM
    maintenance_work_mem: intUNIT # default: 4% from total RAM
    max_stack_depth: intUNIT # default: none, PostgreSQL default: 2MB. Suitable value is $(($(ulimit -s)-2048))
    shared_preload_libraries: [ string, ... ] # default: none
    effective_io_concurrency: int # default: 2 (for HDD RAID 10). For SSD set > 100
    max_wal_size: intUNIT # default: none (PostgreSQL default: 1GB)
    random_page_cost: float # default: none, PostgreSQL default: 4.0 (suitable for HDD). For SSD set to 1.1 - 1.3
    effective_cache_size: intUNIT # default: 1/2 RAM
    log_timezone: "string" # default: W-SU (MSK)
    track_activity_query_size: int # default: none (PostgreSQL default: 1024)
    autovacuum_max_workers: int # default: 3 (change requires restart)
    autovacuum_vacuum_threshold: int # default: 50
    autovacuum_analyze_threshold: int # default: 50
    autovacuum_vacuum_scale_factor: float # default: 0.2
    autovacuum_analyze_scale_factor: float # default: 0.1
    datestyle: "string" # default: 'iso, dmy'
    timezone: "string" # default: W-SU (MSK)
    default_text_search_config: string # default: pg_catalog.russian
    archive_command: "string" # default: "cp %p /var/lib/pgsql/X.X/pg_archive/%f"
    wal_keep_segments: int # default: 32
    wal_log_hints: bool # default: false
    deadlock_timeout: "string" # default: none (PostgreSQL default: time: 1s)
    # нижеуказанные переменные эффективны только при "postgresql_extended_logging: true"
    log_min_duration_statement: int # default: 1000
    log_checkpoints: bool # default: on
    log_connections: bool # default: if postgresql_pcmk_enable then off else on
    log_disconnections: bool # default: if postgresql_pcmk_enable then off else on
    log_lock_waits: bool # default: on
    log_temp_files: int # default: 0

pg_stat_statements: {} # параметры модуля pg_stat_statements (например, track: all)

postgresql_datadir: "/path" # (default: /var/lib/pgsql/<version>/data) Каталог с базой
postgresql_encoding: "string" # (default: utf8) Кодировка инстанса
postgresql_extended_logging: bool # (default: false) Включить расширенное журналирование
postgresql_hba_enable: bool # Включать ли управление файлом pg_hba; default: true

postgresql_hba_tcp: # HBA для удаленных tcp-соединений с аутентификацией md5
  - { db: 'string', user: 'string', address: 'CIDR' [, method: 'string'] }

postgresql_hba_tcp_local: # HBA для локальных tcp-соединений с аутентификацией md5
  - { db: 'string', user: 'string' }

postgresql_hba_tcp_ident: # HBA для удаленных tcp-соединений с аутентификацией ident
  - { db: 'string', user: 'string', address: 'CIDR' }

postgresql_ident_local: # peer/ident map для локальных соединений socket
  - { map: 'string', sysuser: 'string', pguser: 'string' }
# для локальных подключений использовать map 'supervisor',
# для удалённых - 'remote'

postgresql_iptables_enable: bool # (default: true) Включать ли кастомную цепочку iptables
postgresql_locale: "string" # (default: ru_RU.UTF-8) Локаль для БД по-умолчанию
postgresql_lc_messages: "string" # (default: en_US.UTF-8) Локаль для сообщений

postgresql_pgpass_entries: # Добавить пользователю postgres файл .pgpass
  - hostname: string # default: '*'
    port: int # default: '*'
    database: string # default: '*'
    username: string # default: '*'
    password: string # MANDATORY

postgresql_recovery_conf:
  primary_conninfo:
    host: string # MANDATORY
    port: int # default: 5432
    user: string # default: replicator
    application_name: string # default: ansible_nodename.split('.')[0]
    keepalives_idle: int # default: 20
    keepalives_interval: int # default: 5
    keepalives_count: int # default: 5
  trigger_file: string # default: not set
  recovery_min_apply_delay: time # default: not set; valid units for this parameter are "ms", "s", "min", "h", and "d"
  recovery_target_timeline: string # default: 'latest'
  restore_command: string # default: not set
  standby_mode: on|off # default: on

postgresql_reload_direct: bool # (default: false) выполнить reload через pg_ctl после изменений кофингурации

postgresql_repack_tables: # Включение периодического выполнения pg_repack на указанных таблицах
  - { db: 'string', tables: [ 'string', 'string', ... ], cron: 'string' } # где строку для cron указать в обычном формате cronjob '* * * * *'

postgresql_replication_enable: bool # (default: false) Включение секций конфига, нужных для репликации.
    # Файл recovery.conf автоматически не создаётся и репликация не настраивается!

postgresql_roles:
  - name: string # PostgreSQL user (role) name
    password: string # (default: empty) password (plaintext)
    attrs: string # (default: LOGIN) (e.g. LOGIN,REPLICATION) See all possible values on
                  # https://docs.ansible.com/ansible/latest/modules/postgresql_user_module.html?highlight=role_attr_flags
    state: bool # (default: true) the user (role) state.

postgresql_db:
  - name: string # database name
    owner: string # (default: postgres) database OWNER
    ext: [] # optionally add postgresql extensions to database

postgresql_rsyslog_address: "string|ipv4" # (default: none) Адрес сервера rsyslog. Обязателен если postgresql_extended_logging.
postgresql_rsyslog_port: int # (default: 514)

postgresql_user: # default: empty
  name: string # default: postgres
  ssh_key_type: dsa|ecdsa|ed25519|rsa # default: ed25519

postgresql_version: int.int # (default: 9.6) Версия PostgreSQL для развёртывания и поддержки

postgresql_walarchive:
  server: "ipv4" # (REQUIRED) Адрес архивного сервера
  user: "string" # (default: "walarchive") Пользователь для архивирования WAL
  dir: "string" # (default: {{ ansible_nodename.split('.')[0] }}) Каталог для архивов на сервере
```

## Кластер Pacemaker

### Интро

  Включённые в данную роль скрипты позволяют настроить кластеризацию PostgreSQL с использованием Pacemaker и его "родного" (но слегка модифицированного) resource agent'а "pgsql". Кластер будет состоять из 3-х нод, при этом один слейв можно сделать "отстающим" (см. параметр конфигурации PostgreSQL 'recovery_min_apply_delay') - удобно для быстрого восстановления больших баз в некоторых ситуациях (например, ошибочного выполнения DROP DATABASE). *Кластер инициализируется вручную, роль только предоставляет необходимые скрипты.*

  Перед началом работ по развёртыванию или обслуживанию кластера крайне желательно ознакомиться с основными принципами устройства стека Pacemaker, а также со статьёй о resource-agent'е pgsql.

  http://clusterlabs.org/
  http://clusterlabs.org/quickstart-redhat.html
  http://clusterlabs.org/doc/en-US/Pacemaker/1.1-pcs/html-single/Clusters_from_Scratch/index.html
  https://wiki.clusterlabs.org/wiki/PgSQL_Replicated_Cluster

  Затем требуется определиться с IP-адресами: на каждый кластер нужен один адрес для клиентских соединений и (опционально) один адрес в отдельном VLAN для репликации. Вписываем эти адреса в соответствующие переменные.
### Переменные
```yaml
postgresql_pcmk_enable: bool # (default: false) Включить кластеризацию. Выставить true;
postgresql_pcmk_ip_main: ipv4 # MANDATORY if postgresql_pcmk_enable. Виртуальный IPv4-адрес для запросов к БД;
postgresql_pcmk_if_main: ipv4 # Сетевой интерфейс для postgresql_pcmk_ip_main; default is ansible_default_ipv4['interface']
postgresql_pcmk_ip_repl: ipv4 # (default: none) Виртуальный IPv4-адрес для репликации;
		# если не указан -- используется postgresql_pcmk_ip_main
postgresql_pcmk_if_repl: ipv4 # Сетевой интерфейс для postgresql_pcmk_ip_repl; default is ansible_default_ipv4['interface']

postgresql_pcmk_vpc_network: string # MANDATORY if GCP
postgresql_pcmk_force_ra_update: bool # (default: false) Форсировать обновление ресурс-агента
postgresql_pcmk_ra_org: string # Подкаталог в /usr/lib/ocf/resource.d/ длф размещения агентов (например, название организации)
postgresql_pcmk_force_pcs_update: bool # (default: false) Форсировать обновление скрипта инициализации кластера

postgresql_pcmk_rmlock_enable: bool # (default: false) Автоматически удалять PGSQL.lock при PGSQL-status: STOP
```
### Настройка доступов для репликации
```yaml
postgresql_roles:
  - name: replicator
    password: <PASSWORD>
    attrs: "LOGIN,REPLICATION"

postgresql_pgpass_entries:
  - username: replicator
    password: <PASSWORD>

postgresql_hba_tcp:
  - db: replication
    user: replicator
    address: <CIDR>
```
### Копирование базы с мастера на реплики
Скрипту в качестве параметра передаём IP-адрес текущего мастера (запустить от postgres или root)
```shell
/srv/southbridge/bin/pgsql-pcmk-slave-copy.sh MASTER_IPADDR
```
Затем не забыть остановить сервис postgresql на мастере
```shell
sudo -iu postgres /usr/pgsql-9.6/bin/pg_ctl -D /var/lib/pgsql/9.6/data stop
```
### Развёртывание кластера Pacemaker
`[all]` - выполнять на всех нодах кластера; `[one]` - выполнять только на одной ноде

Сначала надо задать пароль пользователя hacluster (должен быть одинаков на всех нодах), запустить сервис *Pacemaker Configuration System* и инициализировать кластер (имена нод должны совпадать с выводом `uname -n`):
```
[all] echo PASSWORD | passwd --stdin hacluster
[all] systemctl enable --now pcsd.service
[all] systemctl restart iptables.service
[one] pcs cluster auth NODE1 NODE2 NODE3 -u hacluster -p PASSWORD --force
[one] pcs cluster setup --force --name CLUSTER_NAME NODE1 NODE2 NODE3
[one] pcs cluster start --all
```
После этого можно потыкать некоторые команды для просмотра статуса и убедиться, что пустой кластер поднялся и чувствует себя нормально, а затем включить сервисы corosync и pacemaker:
```
[one] pcs quorum status
[one] pcs cluster status
[one] pcs status
[all] systemctl enable corosync.service && systemctl enable pacemaker.service
```
Затем следует инициализировать специфические ресурсы RA pgsql, выполнив предоставленный ролью скрипт
```
[one] /srv/southbridge/scripts/pgsql.pcs
```

### Управление кластером

Просмотреть состояние ресурсов кластера и их атрибутов:
```shell
crm_mon -Afr1
```
Если нужно остановить инстанс PostgreSQL на ноде, то это можно сделать через задание ограничений (constraints)
```shell
pcs resource ban PGSQL NODE1
```
Просмотр ограничений
```shell
pcs constraint show
```
Также можно ограничить только возможность апгрейда ноды до мастера:
```shell
pcs resource ban PG-MASTER NODE1 --master
```
Снятие ограничений можно произвести командой
```shell
pcs resource clear PGSQL NODE1
```
Для **подключения реплики** (например, для ввода в строй бывшего мастера после переключения) написан скрипт (запускать без параметров):
```shell
/srv/southbridge/bin/pgsql-pcmk-slave-copy.sh
```
в большинстве случаев он сделает всё сам. И да, никакого pg_rewind, только дубовый pg_basebackup

При выполнении каких-то ручных действий очень пригодится команда, сбрасывающая ошибки ресурсов (это что-то вроде переподключения ресурса к ноде); можно сбросить ресурс на отдельной ноде или глобально:
```shell
pcs resource cleanup PGSQL --node NODE1
pcs resource cleanup
```
Также будет очень полезной команда, переводящая одну или все ноды в "режим обслуживания"
```shell
# Одну ноду
pcs node maintenance NODE1
# Все ноды
pcs node maintenence --all
# Как альтернатива - весь кластер
pcs property set maintenance-mode=true
# Вывести из режима обслуживания
pcs node unmaintenance NODE1
```

### Медленная реплика: концепт

  "Медленной репликой" в настоящем документе называется реплика, у которой в recovery.conf присутствует параметр `recovery_min_apply_delay`. Цитата из документации:

> По умолчанию резервный сервер восстанавливает записи WAL ведущего настолько быстро, насколько это возможно. Иногда полезно иметь возможность задать задержку при копировании данных, например, для устранения ошибок, связанных с потерей данных. Параметр позволяет задать эту задержку, указав период времени в миллисекундах (по умолчанию) или иных единицах измерения. Например, если установить значение 5min, резервный сервер будет воспроизводить фиксацию транзакции не раньше, чем через 5 минут (судя по его системным часам) после времени фиксации, сообщённого главным.

> Задержка добавляется, как только восстанавливаемая база данных достигает согласованного состояния, и исключается, когда резервный сервер переключается в режим основного. С момента переключения резервный сервер завершает восстановление незамедлительно.

### Медленная реплика: использование

  Для включения данного режима необходимо создать на реплике, выбранной под роль "медленной", файл-флаг, который укажет ресурс-агенту, что нужно добавить в recovery.conf нужный параметр; затем следует перезапустить на ней ресурс PGSQL. Также вы можете счесть полезным заблокировать на этой ноде возможность апгрейда до мастера (если считаете, что время на накат лога после промоута слейва будет недопустимо большим).
```shell
sudo -iu postgres touch /var/lib/pgsql/.lag
pcs resource ban PGSQL SLOW_NODE
pcs resource clear PGSQL SLOW_NODE
# pcs resource ban PG-MASTER SLOW_NODE --master
```
По-умолчанию (прописанному в RA) величина замедления составляет 1 час, но вы можете указать любое разумное значение
```shell
pcs resource update PGSQL apply_delay="40min"
pcs resource show PGSQL
```
> Valid units for this parameter are "ms", "s", "min", "h", and "d"

**`ACHTUNG!`** При выполнении `pcs resource update` ресурс будет молча перезапущен на всех нодах, и инстансы PostgreSQL вместе с ним. При этом может смениться мастер. Короче, на продакшне в ЧНН такое лучше не делать.

  Также обратите внимание, что после всяческих пертурбаций (как-то: смена мастера, перезапуск ресурсов и проч.) атрибут PGSQL-data-status на медленной реплике будет находиться в состоянии `DISCONNECT` в течение времени, необходимого для полного наката лога (== времени отставания). Это нормально, и не говорит о неисправности репликации. Побочный эффект-с.
```
Node Attributes:
* Node SLOW_NODE:
    + PGSQL-data-status                 : DISCONNECT
    + PGSQL-receiver-status             : ERROR
    + PGSQL-status                      : HS:alone  
    + master-PGSQL                      : -INFINITY 
```

### Медленная реплика: откат

  При необходимости откатить инстанс СУБД назад на любой момент времени в пределах значения recovery_min_apply_delay (например, после непреднамеренного выполнения DROP DATABASE) можно действовать следующим образом:

Баним ресурс PGSQL в последовательности: медленный слейв - нормальный слейв - мастер.
```shell
pcs resource ban PGSQL SLOW_NODE
pcs resource ban PGSQL NODE2
pcs resource ban PGSQL MASTER_NODE
```
Убеждаемся, что СУБД остановлена
```shell
crm_mon -Afr1
```
Дальнейшие работы производим на бывшей "медленной реплике". Сначала правим файл **recovery.conf** (время, на которое желаем восстановиться, разумеется, указываем своё)
```diff
-standby_mode = 'on'
+standby_mode = 'off'
 primary_conninfo = 'host=192.0.2.102 port=5432 user=replicator application_name=SLOW_NODE keepalives_idle=60 keepalives_interval=5 keepalives_count=5'
 restore_command = 'cp /var/lib/pgsql/9.6/pg_archive/%f %p'
 recovery_target_timeline = 'latest'
-recovery_min_apply_delay = '20min'
+recovery_target_time = '2020-08-12 12:30:00'
+recovery_target_action = 'promote'
```
Запускаем СУБД вручную; ждём, пока лог накатится до указанной точки (следить можно через лог PostgreSQL); убеждаемся, что нужные данные на месте; останавливаем СУБД
```shell
sudo -iu postgres
/usr/pgsql-9.6/bin/pg_ctl -D /var/lib/pgsql/9.6/data start
[... psql checks ...]
/usr/pgsql-9.6/bin/pg_ctl -D /var/lib/pgsql/9.6/data stop
```
**Принудительно выставляем PGSQL-data-status в значение `"LATEST"`**
```shell
crm_attribute -l forever -N SLOW_NODE -n "PGSQL-data-status" -v "LATEST"
```
Снимаем все баны c нового мастера (бывшего "медленного слейва")
```shell
pcs resource clear PG-MASTER SLOW_NODE
pcs resource clear PGSQL SLOW_NODE
```
Собственно, всё - ресурсы на новой мастер-ноде должны запуститься в нормальном порядке. После того, как всё устаканится, можно подключить слейвы (поскольку временны'е линии лога разошлись, их нужно заново копировать с нового мастера), а затем снять с них бан.
```shell
/srv/southbridge/bin/pgsql-pcmk-slave-copy.sh
pcs resource clear PGSQL NODENAME
```
## Подсказки
#### `postgresql_pcmk_rmlock_enable`
Просмотр нужных параметров:
```shell
pcs property show --full | grep cluster-recheck-interval
pcs status resources --full | grep 'Meta Attrs'
```
Установка параметров:
```shell
pcs property set maintenance-mode=true
pcs resource meta PGSQL failure-timeout=120
pcs property set cluster-recheck-interval=60
pcs property set maintenance-mode=false
```
## Скрипты и утилиты
+ `pgmetrics` collects a lot of information and statistics from a running PostgreSQL server and display it in easy-to-read text format or export it as JSON and CSV for scripting (https://pgmetrics.io/);
+ `pgstat` is a vmstat-like tool for PostgreSQL (https://github.com/gleu/pgstats);
+ `/usr/local/bin/pgsql-lock-view.sh` просмотр блокировок (обёртка над https://wiki.postgresql.org/wiki/Lock_Monitoring);
+ `/srv/southbridge/bin/pgsql-pcmk-slave-copy.sh` копирование экземпляра с мастера на слейв (обёртка над `pg_basebackup`)
## Зависимости
-

## Лицензия

BSD
