mysql
=====
Install and configure mysql
## Variables
```yaml
mysql_flavor: string # rh-mariadb only supported

mysql_version:
 - float

mysql_service:
  limitnofile: unit # default: 262144

mysql_percona_packages: []

mysql_cnf:  # Config for all versions
  key: value

mysql_cnf_ver:  # Version-specific config
  <mysql_version>:
    key: value

```
