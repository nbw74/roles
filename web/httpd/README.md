# httpd
Роль для развёртывания типового веб-хостинга с веб-сервером httpd (Apache)
## Variables
```yaml
httpd_add_packages: []

httpd_listen_add:
  - addr: ipv4
    port: int

remi_php_version: int # Версия PHP для установки из репозитория remi. Например, 56, 71 и т.д.

selinux_state: "enforcing|permissive|disabled" # default: "disabled"
timezone: "string" # default: 'Europe/Moscow' :Временна'я зона, устанавливаемая в php.ini
```
## Tags
`awstats` `conf` `logrotate` `packages` `php` `remi` `selinux` `selinux_ports` `services` `templates`
## Dependencies
Роль "nginx" (включена в meta)

