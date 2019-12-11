redis
=====
Роль для конфигурации **redis**
- устанавливает redis
- настраивает redis 
- настраивает _ресурс-агент_ redis для кластера pacemaker+corosync
## Переменные
```yaml
redis_conf:
  bind: IPv4 # default: 127.0.0.1
  protected_mode: bool # default: true
  port: int # default: 6379
  tcp_backlog: int # default: 511; количество подключений (?)
  unixsocket: string # default: undefined; путь к unix-сокету, по умолчанию не использует сокет
  unixsocketperm: int # default: 700
  timeout: int  # default: 0; время, в течение которого держать соединение открытым, 0 выключает timeout
  tcp_keepalive: int # default: 300; период, используемый для отправки ACK (секунд).
  daemonize: bool # default: false; при включенном параметре redis работает в режиме демона
  pidfile: path # default: /var/run/redis/redis-server.pid; путь до pid-файла 
  loglevel: string # default: warning; уровень логирования (может принимать значение debug, verbose, notice, warning)
  logfile: path # default: /var/log/redis/redis.log; путь к лог-файлу 
  databases: int # default: 16; количество баз данных
  stop_writes_on_bgsave_error: bool # default: true
  rdbcompression: bool # default: true; сжатие баз при сбросе БД на диск
  dbfilename: string # default: dump.rdb; название файла БД
  dir: path # default: /var/lib/redis; директория для хранения БД
  maxmemory: int # default: undefined; лимит использования памяти в байтах
  maxmemory_policy: string # default: noeviction; политика при достижении лимита памяти (volatile-lru, allkeys-lru, volatile-lfu, allkeys-lfu, volatile-random, allkeys-random, volatile-ttl, noeviction)
  maxmemory_samples: int # default: 5; количество ключей, используемых для определения lru, lfu (#LRU means Least Recently Used, LFU means Least Frequently Used)
  appendonly: bool # default: false; включает режим aof 
  appendfilename: string # default: appendonly.aof; название файла для сброса БД в режиме aof
  appendfsync: string # default: everysec; режим сброса БД в aof (always, no, everysec)
  no_appendfsync_on_rewrite: bool # default: no; опция предотвращения вызова fsync () в основном процессе пока BGSAVE or BGREWRITEAOF выполняются (при проблемах с I/O в режиме aof).
  slowlog_log_slower_than: int # default: 10000; записывать в slow-логи запрос дольше, чем указанное время
  slowlog_max_len: int # default: 128; длина slow-лога

redis_save: # параметр сохранения БД на диск <секунд> <ключей>, чтобы отключить сохранение на диск, параметр нужно оставить пустым
  - 900 1     # по умолчанию сохраняет через 900 секунд, если хотя бы один ключ изменился
  - 300 10    # сохраняет через 300 секунд, если изменились 10 ключей
  - 60 10000  # сохраняет через 60 секунд, если изменились 10000 ключей

redis_includes: [] # укажите в скобках путь до файла с инклюдом дополнительных параметров

redis_pcmk_ra_org: string # Подкаталог в /usr/lib/ocf/resource.d/ длф размещения ресурс-агента (например, название организации)

redis_pcmk_vip: # когда словарь не пустой -- включает ресурсы кластера pacemaker
  ip: ipv4 # Virtual IP for pacemaker cluster; MANDATORY
  nic: string # Network interface for virtual ip; default: ansible_default_ipv4['interface']
  cidr_netmask: int # CIDR prefix for virtual ip; default: ipaddr('prefix') of ansible_default_ipv4
```
## Кластер на Pacemaker
Минимальная конфигурация (также см. роль `pcmk`):
```ini
[my-redis]
redis-1.example.com
redis-2.example.com
redis-3.example.com
```
```yaml
pcmk_pool: my-redis # имя группы в hosts, минимум 3 ноды

redis_conf:
  bind: 0.0.0.0
  protected_mode: false

redis_service_enabled: false

redis_pcmk_vip:
  ip: <CLUSTER_VIRTUAL_IPV4>
```
