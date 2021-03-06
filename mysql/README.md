mysql
=====
Install and configure mysql
## Variables
```yaml
mysql_flavor: string # rh-mariadb only supported

mysql_version:
 - float

mysql_service:
  limitnofile: uint # default: 262144
  nostart: bool # default: False

mysql_percona_packages: []

mysql_cnf:  # Config for all versions
  key: value

mysql_cnf_ver:  # Version-specific config
  <mysql_version>:
    key: value

mysql_db:
  - name: string
    encoding: string   # default: utf8
    collation: string  # default: utf8_general_ci
    login_unix_socket: path # default: '/var/lib/mysql/mysql.sock'
    state: bool

mysql_user:
  - name: string
    password: string
    password_file: bool
    priv: string # see https://docs.ansible.com/ansible/latest/modules/mysql_user_module.html
    host: string # default: '%'
    login_unix_socket: path # default: '/var/lib/mysql/mysql.sock'
    state: bool
```
