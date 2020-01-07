pgbouncer
=========
PgBouncer setup
### Actions
* Setup **pgdg** yum repository
* Install pgbouncer and postgresql-client packages
* Setup pgbouncer configuration files
## Variables
```yaml
postgresql_version: int[.int] # REQUIRED

pgbouncer_config: # pgbouncer.ini: [pgbouncer] section
  unix_socket_dir: path # Default: /var/run/pgbouncer; if set to 'none' disable socket.
  listen_addr: ipv4 # default: no listen on IPv4; recommended: 127.0.0.1; * means all IPs
  listen_port: int # default: 6432
  log_connections: int # default: 0
  log_disconnections: int # default: 0
  server_lifetime: int # default: 3600
  server_idle_timeout:  int # default: 600
  idle_transaction_timeout: int # Default: not set; close connections which are in "IDLE in transaction" state longer than int seconds
  max_client_conn: int # Default: 100
  default_pool_size: int # Default: 40
  pool_mode: string      # When server connection is released back to pool: session (default), transaction, statement

pgbouncer_db: # pgbouncer.ini: [databases] section and userlist.txt
  - name: string # Database name (REQUIRED)
    host: address # Database host (REQUIRED)
    port: int # Default: 5432
    user: string # Optional
    pool_size: int # Optional (using {{ pgbouncer_config.default_pool_size }})
    custom: string # Optional custom connection parameters (see 'connect string params' in pgbouncer.ini)

pgbouncer_user: # userlist.txt
  - name: string
    password: string # Optional

pgbouncer_hba_line: # bouncer_hba.conf (see https://pgbouncer.github.io/config.html)
  - type: string # local | host (default) | hostssl | hostnossl
    database: string # all | sameuser (default) | <string>
    user: string # all | <string>
    address: ipv4 # Optional
    method: string # trust | reject | md5 (default) | password | peer | cert

pgbouncer_enable: bool # default: true - Enable pgbouncer service

pgbouncer_vhost_compat: bool # default: false; vhost role compatibility 
```
