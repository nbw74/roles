# php-fpm
Роль для развёртывания бэкенда PHP-FPM для веб-сервера Nginx
## Variables
```yaml
remi_php_version: int #  Версия PHP для установки из репозитория remi. Например, 56, 71 и т.д.

php_fpm_memcached_client: bool # default: false :Установить и настроить библиотеку клиента
                               # memcached для PHP
php_fpm_memcached_nubmer_of_replicas: int # default: 1 :Настроить количество серверов memcached;
                               # 0 - одиночный сервер, 1 - пара (одна реплика)
php_fpm_memcached_default: bool # default: false :Прописать клиент memcached как хэндлер в шаблон
                                # пула и указать серверы из нижеуказанных переменных
php_fpm_memcached_server_1: "ipv4|string|fqdn" # default: localhost4
php_fpm_memcached_port_1: int # default: 11211
php_fpm_memcached_server_2: "ipv4|string|fqdn" # default: <none>
php_fpm_memcached_port_2: int # default: 11211

php_fpm_force_templates: bool # default: true :Форсирование копирования шаблона конфигурационного
                              # файла пула
selinux_state: "enforcing|permissive|disabled" # default: "disabled"
timezone: "string" # default: 'Europe/Moscow' :Временна'я зона, устанавливаемая в php.ini
```
## Tags
`conf` `index` `logrotate` `memcached` `packages` `php` `remi` `selinux` `selinux_ports` `services` `templates` `timezone`
## Dependencies
Роль "nginx" (включена в meta)

