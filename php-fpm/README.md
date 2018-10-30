# php-fpm
Роль для развёртывания бэкенда PHP-FPM для веб-сервера Nginx
## Variables
```yaml
php_fpm_add_packages: [ string, ... ] # default: none -- Additional packages

php_logrotate_laravel_enable: bool # default: false

selinux_state: "enforcing|permissive|disabled" # default: "enforcing"
```
## Tags
`awstats`, `index`, `logrotate`, `packages`, `selinux`, `services`
## Dependencies
* nginx
* php

