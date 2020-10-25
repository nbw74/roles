# php
Роль для установки PHP
## Variables
```yaml
php_remi_version: int #  Версия PHP для установки из репозитория remi

php_add_packages: []

php_custom_modules: []  # List of full paths for custom PHP modules loading
                        # (e.g. copied with `localfiles` role)

php_memcached_client: bool # default: false :Установить и настроить библиотеку клиента
                           # memcached для PHP
php_memcached_nubmer_of_replicas: int # default: 1 :Настроить количество серверов memcached;
                           # 0 - одиночный сервер, 1 - пара (одна реплика)

php_oob: bool # default: false -- Use PHP from OS distribution

php_options:
  - { section: 'string', option: 'string', value: 'string' }

timezone: "string" # default: 'Europe/Moscow' :Временна'я зона, устанавливаемая в php.ini
```
## Tags
`memcached`, `packages`, `timezone`
## Dependencies
none

