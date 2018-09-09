# php
Роль для установки PHP
## Variables
```yaml
php_remi_version: int #  Версия PHP для установки из репозитория remi

php_memcached_client: bool # default: false :Установить и настроить библиотеку клиента
                           # memcached для PHP
php_memcached_nubmer_of_replicas: int # default: 1 :Настроить количество серверов memcached;
                           # 0 - одиночный сервер, 1 - пара (одна реплика)

php_oob: bool # default: false -- Use PHP from OS distribution

timezone: "string" # default: 'Europe/Moscow' :Временна'я зона, устанавливаемая в php.ini
```
## Tags
`memcached`, `packages`, `timezone`
## Dependencies
none

