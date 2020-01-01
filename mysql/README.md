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

mysql_percona_packages: []

mysql_cnf:  # Config for all versions
  key: value

mysql_cnf_ver:  # Version-specific config
  <mysql_version>:
    key: value

mysql_users:
  - name: string
    password: string
    priv: string # see https://docs.ansible.com/ansible/latest/modules/mysql_user_module.html
    host: string # default: '%'
    login_unix_socket: path # default: '/var/lib/mysql/mysql.sock'
    state: bool
```
