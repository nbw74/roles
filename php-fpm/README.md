<!-- vim: set ft=ansible: -->
# php-fpm
Роль для развёртывания бэкенда PHP-FPM для веб-сервера Nginx
## Variables
```yaml
php_fpm_add_packages: [ string, ... ] # default: none -- Additional packages

php_laravel_units: # Laravel queue worker using systemd
  - name: "string" # default: laravel-queue-worker; Unit name
    description: "string" # optional
    args: "string" # optional arguments after "queue:work"
    state: bool # default: yes

php_logrotate_laravel_enable: bool # default: false

selinux_state: "enforcing|permissive|disabled" # default: "enforcing"
```
## Tags
`awstats`, `index`, `logrotate`, `packages`, `selinux`, `services`
## Dependencies
* nginx
* php

