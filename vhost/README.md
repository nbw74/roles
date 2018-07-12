<!-- vim: set ft=ansible: -->
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
vhost_backend: "php-fpm|apache|reverse-proxy"   # default is "php-fpm"
vhost_basedir: "filesystem_path"                # default is "/var/www"
vhost_frontuser: "string"                       # default is "nginx"
vhost_backuser: "string"                        # default is "apache"
vhost_logbuffer: "intUNIT"                      # default is "128k"
vhost_db_pgsql_admin_user: "string"             # mandatory if use postgresql
vhost_db_pgsql_admin_pass: "string"             # mandatory if use postgresql
vhost_db_mysql_admin_user: "string"             # mandatory if use mysql
vhost_db_mysql_admin_pass: "string"             # mandatory if use mysql
vhost_git_server: "string"                      # mandatory if use git
vhost_git_path: "filesystem_path"               # default is "/var/lib/git"
vhost_git_group: "string"                       # default is "developers"
vhost_ddns_server: "string"                     # mandatory if use ddns
vhost_default_ddns_zone: "string"               # mandatory if use ddns, git, redmine
vhost_ddns_key_name: "string"                   # default is "ddns_key"
vhost_ddns_key_algorithm: "string"              # default is "hmac-md5"
vhost_ddns_key_secret: "string"                 # mandatory if use ddns
```
## Virtual host data structure
```yaml
vhost:
- name: example.org # mandatory
  alias: # optional
    - nose.example.org
  apache:
    port: 8888 # optional (if use apache as vhost_backend)
  crypto: none|redirect|both # optional; default is "none"
  crypto_mobile: none|redirect|both # optional; default is 'crypto' value
  db:
    type: mysql|postgresql # mandatory if use database
    host: db.example.org # mandatory
    port: 1234 # optional; default is 3306 if use mysql and 5432 if use postgresql
    name: exampleorg # mandatory
    pass: password # mandatory
    encoding: utf8 # optional; default is "utf8" for mysql
    collation: utf8_general_ci # optional; default is "utf8_general_ci" for mysql
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
  disable: bool # optional; disable website temporarily (return 503)
  fpm: # mandatory if use php-fpm
    port: 9001 # mandatory; next free port
    pm: static|dynamic|ondemand # optional; default is "ondemand"
    max_children: 40 # optional
    start_servers: 5 # optional
    min_spare_servers: 5 # optional
    max_spare_servers: 32 # optional
    process_idle_timeout: 10s # optional
    max_requests: 0 # optional
    template: "string" # fpm configuration; see below
  index: "myindex.php" # optional; default is "index.php"
  legacy: bool # optional; don't force web-server config templates
  listen: # optional; default is first public IP (or private, if no public addresses)
    - ipaddr: 192.0.2.10|all # 'all' is special word
      port: 80 # optional; default is 80 or 443 if use crypto
  memcached: # optional if use memcached
    server1: address # default is "localhost4"
    port1: 11211
    server2: address # default is none
    port2: 11211
  mobile: bool # optional; default is 'no'; enable mobile version config with same site root
  nginx_snippet: | # insert configuration block into nginx vhost config in the 'server' context (before "backend section")
    block
  password: string # optional; set password for <user> (changed only on_create)
  php_value: # optional
    - key: 'string'
      value: 'string'
  proxy_host_header: external|internal|<string> # default: external
  proxy_pass: "URI" # mandatory if use reverse-proxy vhost_backend
  redmine: # optional
    title: "string" # optional; default is "vhost.name" without vhost_default_ddns_zone$
    description: "string" # mandatory if use redmine
    id: "[-a-z]+" # optional; default is filtered "vhost.name" s/\./-/g
  repo: # optional
    type: git|svn
    name: example.org
  save_handler: files|memcached|none # optional; default is "files"
  state: bool # optional; default is 'yes'
  user: example # optional; default is "name" value
  webcheck: # optional
    enable: bool # default is circuit-dependent
    content: "string" # mandatory if use webcheck
    content_mobile: "string" # mandatory if use webcheck
    url: "string" # optional
    url_mobile: "string" # optional
    fqdn: "string" # optional
    fqdn_mobile: "string" # optional
    notify: "string" # optional
    zone: "string" # default is common_icinga2_satellite_zone value
  webroot: "www/public" # optional; default is "www"

```
### fpm['template']
Nginx website configuration for use with php-fpm PHP backend. Currently supported:
+ generic (default)
+ opencart
+ `filename.conf` (your custom configuration file placed in `/etc/nginx/include.d/`)
## Required OS
CentOS 7
## Required packages
+ bzip2
+ python-dns
+ python-psycopg2
+ MySQL-python
## Tags
`archive` `conf` `crypto` `db` `ddns` `redmine` `repo` `user` `version` `webcheck` `wiki`

