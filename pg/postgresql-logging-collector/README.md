postgresql-logging-collector
============================
+ настраивает rsyslog для приёма логов на 514/udp;
 + кладёт логи с `local5` в `/var/log/pglog/%HOSTNAME%`;
+ скачивает pgBadger с гитхаба;
 + создаёт задание cron для регулярного запуска pgBadger;
+ настраивает Nginx с `auth_basic` для отдачи результатов анализа логов pgBadger'ом.
## variables
```yaml
plc_nginx: # MANDATORY
  htpasswd_users:
    <name>: <password> # для удаления пользователя используйте 'false' без кавычек вместо 'password'
  listen: <nginx_listen_string> # default: "80"
  server_name: <ip_or_fqdn> # default: ansible_default_ipv4.address

plc_reports:
  options: "string" # default: none
  path: <path> # default: "/opt/pgbadger/reports"
  title: "string" # default: 'NOCOMPANY'

# Useful options:
# --nosession --truncate=all (CS)
# --nouser bacula (WM)

plc_pgbadger_update: bool # default: false
plc_pgbadger_version: string # This can be the literal string HEAD (default), a branch name, a tag name.
```
