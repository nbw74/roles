# php-fpm
Роль для развёртывания бэкенда PHP-FPM для веб-сервера Nginx
## Variables
```yaml
php_fpm_add_packages: [ string, ... ] # default: none -- Additional packages

php_laravel_units: # Laravel queue worker using systemd
  - name: string # default: laravel-queue-worker; Unit name
    description: string # optional
    artisan_path: string # path to artisan relatively to www/ (default: artisan)
    command: string # default: 'queue:work'
    args: string # optional arguments after `command` (e.q. '--queue=export --tries=1')
    state: bool # default: yes

selinux_state: "enforcing|permissive|disabled" # default: "enforcing"
```
## Tags
`awstats`, `index`, `logrotate`, `packages`, `selinux`, `services`
## Dependencies
* nginx
* php

