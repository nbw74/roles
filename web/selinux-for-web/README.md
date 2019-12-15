# selinux-for-web
Некоторые настройки SELinux для веб-серверов httpd и php-fpm
### Что эта роль делает
* Применяет booleans
* Применяет ports
* Применяет fcontext
### Чего эта роль не делает
* Не ставит кастомные модули
## Variables
```yaml
selinux_custom_booleans:
  - { name: 'boolean_name'[, state: 'bool'] }

selinux_custom_ports:
  - port: uint
    type: string # (http_port_t, postgresql_port_t, ...)
    proto: string # default: 'tcp'

selinux_custom_fcontexts:
  - name: "string" # short description
    setype: "string" # e.g. "httpd_sys_rw_content_t"
    target: "string" # e.g. "/var/www/[-a-zA-Z0-9\.]+/www/web/assets(/.*)?"
```
## Dependencies
-
## Tags
``
