<!-- vim: set ft=yaml.ansible: -->
# vhost
Deploy website virtual host configuration:
+ create website configuration files:
  + Nginx vhost (frontend)
  + Apache vhost (PHP backend)
  + PHP-FPM pool (PHP backend)
  + reverse-proxy Nginx vhost
+ create database for website:
  + MySQL
  + PostgreSQL
    + pgbouncer configuraton
+ add DDNS record
+ create Git repository
+ create Redmine project
+ create Icinga2 webcheck configuration
## Common host variables
```yaml
vhost_apache_port: int                  # default: 8888
vhost_backend: "none|php-fpm|apache|reverse-proxy|bitrix" # default is "php-fpm"
vhost_backuser: "string"                # default is "apache"
vhost_basedir: "filesystem_path"        # default is "/var/www"
vhost_ddns_server: "string"             # mandatory if use ddns
vhost_ddns_key_name: "string"           # default is "ddns_key"
vhost_ddns_key_algorithm: "string"      # default is "hmac-md5"
vhost_ddns_key_secret: "string"         # mandatory if use ddns
vhost_default_ddns_zone: "string"       # mandatory if use ddns, git, redmine
vhost_frontuser: "string"               # default is "nginx"
vhost_git_server: "string"              # mandatory if use git
vhost_git_path: "filesystem_path"       # default is "/var/lib/git"
vhost_git_group: "string"               # default is "developers"
vhost_logbuffer: "intUNIT|none"         # default is "128k"
vhost_logrotate_cake_enable: bool       # default: False
vhost_logrotate_laravel_enable: bool    # default: False
vhost_nuxt_enable: bool                 # default: False; include configuration for nuxt.js

vhost_db_admin:
  pgsql:
    user: "string"             # default is "ansible"
    pass: "string"             # mandatory if use postgresql
  mysql:
    user: "string"             # default is "ansible"
    pass: "string"             # mandatory if use mysql

vhost_gitlab:
  api_url: uri
  api_token: string
```
## Virtual host data structure
```yaml
vhost:
- name: example.org # mandatory
  alias: # optional
    - nose.example.org
  apache:
    port: 8888 # optional (if use apache as vhost_backend)
  backend_enable: bool # default: True
  bitrix_multisite:
    - name: ears.example.org
      crypto: bool
      content: "string"
  cron: # optional; cron tasks for vhost user
    - name: "Task name" # mandatory; description of a crontab entry
      minute: "string" # default: *; minute when the job should run ( 0-59, *, */2, etc )
      hour: "string" # default: *; hour when the job should run ( 0-23, *, */2, etc )
      day: "string" # default: *; day of the month the job should run ( 1-31, *, */2, etc )
      weekday: "string" # default: *; day of the week that the job should run ( 0-6 for Sunday-Saturday, *, etc )
      month: "string" # default: *; month of the year the job should run ( 1-12, *, */2, etc )
      job: "string" # mandatory; the command to execute
      disabled: bool # default: no; if the job should be disabled (commented out) in the crontab
      state: bool # default: yes; whether to ensure the job is present or absent
  crypto: none|redirect|both # optional; default is "none"
  crypto_le: bool # Use Let's Encrypt; default: no
  crypto_mobile: none|redirect|both # optional; default is 'crypto' value
  crypto_wildcard: bool # Use wildcard certificate _<example.org>; default: false
  db:
    type: mysql|postgresql # mandatory if use database
    host: db.example.org # mandatory
    port: 1234 # optional; default is 3306 if use mysql and 5432 if use postgresql
    name: exampleorg # mandatory
    pass: password # mandatory
    encoding: utf8 # optional; default is "utf8" for mysql
    collation: utf8_general_ci # optional; default is "utf8_general_ci" for mysql
    extensions: [ 'string', ... ] # optional if use postgresql
    pgbouncer: # optional if use postgresql
      host: pgbouncer.example.org # mandatory if use pgbouncer
      port: 6432 # optinal
      db_host: 127.0.0.1 # optional (host= in pgbouncer.ini)
      pool_size: 40 # optional (pgbouncer.ini)
      ip: 127.0.0.1/32 # optional (pgbouncer address in pg_hba.conf)
  ddns: # optional
    enable: bool # default is 'no'
    zone: string # default is vhost_default_ddns_zone
    record: string # default is vhost.name minus vhost_default_ddns_zone
    type: A|CNAME|... # default is CNAME
    value: string # default is ansible_fqdn.
  disabled: bool # optional; disable website temporarily (return 503)
  fpm: # mandatory if use php-fpm
    port: 9001 # mandatory; next free port
    pm: static|dynamic|ondemand # optional; default is "ondemand"
    max_children: 40 # optional
    start_servers: 5 # optional
    min_spare_servers: 5 # optional
    max_spare_servers: 32 # optional
    process_idle_timeout: 10s # optional
    max_requests: 0 # optional
    status_path: string # optional
    template: "string" # fpm configuration; see below
  gitlab:
    name: string # default is "vhost.name" without vhost_default_ddns_zone
    path: string # default is "vhost.name" without vhost_default_ddns_zone
    namespace: string # mandatory
    description: string # mandatory
  hosts: bool # add vhost resord in /etc/hosts; IP address set in listen[0] or vhost_default_ipaddr
  idna: bool # Encode server_name in IDNA (Internationalized Domain Names in Applications)
  index: "myindex.php" # optional; default is "index.php"
  legacy: bool # optional; don't force web-server config templates
  listen: # optional; default is first public IP (or private, if no public addresses)
    - ipaddr: 192.0.2.10|all # 'all' is a special word
      port: 80 # optional; default is 80 or 443 if use crypto
  memcached: # optional if use memcached
    server1: address # default is "localhost4"
    port1: 11211
    server2: address # default is none
    port2: 11211
  mobile: bool # optional; default is 'no'; enable mobile version config with same site root
  nginx_301_only: "URI" # Configure 301 redirect to address "URI" instead of "normal" backend
  nginx_auth_basic: # optional
    string: "string" # default: "Restricted"
    user_file: "path" # default: "/etc/nginx/.htpasswd"
    users:
      - name: "string"
        pass: "string"
        state: bool # default: yes
  nginx_http_snippet: | # insert configuration block into nginx vhost config
    block # ... in the 'http' context
  nginx_locations:
    - path: string
      directives: { }
  nginx_options:
    fastcgi_read_timeout: string  # default: 60s
    proxy_connect_timeout: string  # default: 60s
    proxy_read_timeout: string  # default: 90s
    proxy_send_timeout: string  # default: 90s
  nginx_root_location: bool # default: true
  nginx_server_directives: { }
  nginx_server_snippet: | # insert configuration block into nginx vhost config
    block # ... in the 'server' context (before "backend section")
  nginx_static_location: bool # default: true
  nginx_whitelist:
    allow: []
    context: string # server (default) or root (/)
  nuxt: # Create nuxt.js systemd unit file, upstream and other Nginx configuration
    port: uint # start from 5020
  password: string # optional; set password for <user> (changed only on_create)
  php_laravel_units:
    - name: "string" # default: laravel-queue-worker
      enabled: bool # default: yes
  php_value: # optional
    key: value
  proxy_host_header: external|internal|<string> # default: external
  proxy_pass: "URI" # mandatory if use reverse-proxy vhost_backend
  proxy_pass_scheme: bool # Pass X-Forwarded-Proto and X-Scheme headers; default: false
  proxy_set_scheme: bool # Set X-Forwarded-Proto and X-Scheme headers in $scheme value; default: false
  redmine: # optional
    title: "string" # optional; default is "vhost.name" without vhost_default_ddns_zone$
    description: "string" # mandatory if use redmine
    id: "[-a-z]+" # optional; default is filtered "vhost.name" s/\./-/g
  repo: # optional
    type: git|svn
    name: example.org
  save_handler: files|memcached|none # optional; default is "files"
  state: bool # optional; default is 'yes'
  unit:
    port: uint # begin from 8300
  user: example # optional; default is "name" value
  user_id: uint  # optional; default is omitted
  webcheck: # optional
    enable: bool # default is circuit-dependent
    ignore: bool # don't touch existing Icinga2 http check config
    content: "string" # mandatory if use webcheck
    content_mobile: "string" # mandatory if use webcheck
    url: "string" # optional
    url_mobile: "string" # optional
    fqdn: "string" # optional
    fqdn_mobile: "string" # optional
    notify: "string" # optional
    zone: "string" # default is common_icinga2_satellite_zone value
  webroot: "www/public" # optional; default is "www"
  wikimarkup: bool # optional; default: true; write textile markup in wiki file

```
### fpm['template']
Nginx website configuration for use with php-fpm PHP backend. Currently supported:
+ generic (default)
+ opencart
+ phalcon
## Configuration examples
### Simple NginX proxy
```yaml
vhost_backend: "reverse-proxy"

vhost:

- name: example.com
  proxy_pass: "http://inside.example.com"
  proxy_host_header: external
```
## Required OS
CentOS 7
## Required packages
+ bzip2
+ python-dns
+ python-psycopg2
+ MySQL-python
## Tags
`archive` `conf` `crypto` `db` `ddns` `gitlab` `hosts` `redmine` `repo` `user` `version` `webcheck` `wiki`

