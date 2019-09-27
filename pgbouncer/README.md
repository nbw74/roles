pgbouncer
=========
PgBouncer setup
### Actions
* Setup **pgdg** yum repository
* Install pgbouncer and postgresql-client packages
* Setup pgbouncer configuration files
## Variables
```yaml
postgresql_version: int[.int] # default: 11

pgbouncer_config: # pgbouncer.ini: [pgbouncer] section
  unix_socket_dir: path # Default: /var/run/pgbouncer; if set to 'none' disable socket.
  listen_addr: ipv4 # default: no listen on IPv4; recommended: 127.0.0.1; * means all IPs
  listen_port: int # default: 6432
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
  - type: local|host|hostssl|hostnossl
    database: all|sameuser|string
    user: all|string
    address: ipv4 # Optional
    method: trust|reject|md5|password|peer|cert

pgbouncer_enable: bool # default: true - Enable pgbouncer service
```
