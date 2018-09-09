# php-fpm
Роль для развёртывания бэкенда PHP-FPM для веб-сервера Nginx
## Variables
```yaml
php_fpm_add_packages: [ string, ... ] # default: none -- Additional packages

php_fpm_memcached_server_1: "ipv4|string|fqdn" # default: localhost4
php_fpm_memcached_port_1: int # default: 11211
php_fpm_memcached_server_2: "ipv4|string|fqdn" # default: <none>
php_fpm_memcached_port_2: int # default: 11211

selinux_state: "enforcing|permissive|disabled" # default: "enforcing"
```
## Tags
`awstats`, `index`, `logrotate`, `packages`, `selinux`, `services`
## Dependencies
* nginx
* php

