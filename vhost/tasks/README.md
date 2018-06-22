## Tasks notes
### postgresql.yml
Create admin user
```sql
CREATE ROLE vhost_db_pgsql_admin_user LOGIN SUPERUSER ENCRYPTED PASSWORD 'vhost_db_pgsql_admin_pass';
CREATE DATABASE ansible OWNER ansible;
```
### mysql.yml
Create admin user
```sql
GRANT ALL PRIVILEGES ON *.* TO 'vhost_db_mysql_admin_user'@'%' IDENTIFIED BY 'vhost_db_mysql_admin_pass' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```
