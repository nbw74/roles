# vhost
Развёртывание вирт. хоста nginx + php-fpm, nginx + apache, создание базы mysql или postgresql, создание репозитория git
## Data structure
```yaml
vhost_backend: "php-fpm|apache"       # default is "php-fpm"
vhost_basedir: "filesystem_path"      # default is "/var/www"
vhost_frontuser: "string"             # default is "nginx"
vhost_backuser: "string"              # default is "apache"
vhost_logbuffer: "intUNIT"            # default is "128k"
vhost_db_mysql_admin_user: "string"   # mandatory if use mysql
vhost_db_mysql_admin_pass: "string"   # mandatory if use mysql
vhost_git_server: "string"            # mandatory if use git
vhost_git_path: "filesystem_path"     # default is "/var/lib/git"
vhost_git_group: "string"             # default is "developers"

servers:
  - name: example.org # mandatory
    state: yes|no # optional; default is 'yes'
    user: example # optional; default is "name" value
    alias: # optional
      - nose.example.org
    listen: # optional; default is first public IP (or private, if no public addresses)
      - ipaddr: 192.0.2.10
        port: 80 # optional; default is 80
        portcrypto: 443 # optional; default is 443
    webroot: "www/public" # optional; default is "www"
    index: "myindex.php" # optional; default is "index.php"
    mobile: yes|no # optional; default is 'no'; enable mobile version config with same site root
    crypto: none|redirect|both # optional; default is "none"
    repo: git|svn # default: none
    fpm: # mandatory if use php-fpm
      port: 9001 # mandatory; next free port
      pm: static|dynamic|ondemand # optional; default is "ondemand"
      max_children: 40 # optional
      start_servers: 5 # optional
      min_spare_servers: 5 # optional
      max_spare_servers: 32 # optional
      process_idle_timeout: 10s # optional
      max_requests: 0 # optional
      include: "myfpm.conf" # optional; default is "fpm.conf"; use if custom fpm configuration needed (in /etc/nginx/include.d/)
    save_handler: files|memcached # optional; default is "files"
    memcached: # optional if use memcached
      server1: address # default is "localhost4"
      port1: 11211
      server2: address # default is none
      port2: 11211
    db:
      type: mysql|postgresql # mandatory if use database
      host: db.example.org # mandatory
      port: 1234 # optional; default is 3306 if use mysql and 5432 if use postgresql
      name: exampleorg # mandatory
      pass: password # mandatory
      bouncer: pgbouncer.example.org # optional if use postgresql
      encoding: "utf8" # optional; default is "utf8" for mysql
      collation: "utf8_general_ci" # optional; default is "utf8_general_ci" for mysql
```
## Tags
`` `` `` `` `` `` `` `` `` ``
