<!-- vim: set ft=ansible: -->
# bitrix-env
Роль для развёртывания виртуальной машины с пакетом bitrix-env для CMS "Битрикс"

https://www.1c-bitrix.ru/products/env/

## Variables
```yaml
bx_add_packages: [] # install additional packages

bx_mail_alias: "string" # default: none :Почтовый алиас для пересылки почты пользователя bitrix

bx_real_ip_from: [] # default: <RFC-1918 network list>

nginx_allow_status_list: [] # default: <RFC-1918 network list> Список адресов, с которых разрешено
                            # обращение к странице статуса Nginx

php_options: # Global PHP options
  - option: 'string'
    value: 'string'

timezone: "string" # default: "Europe/Moscow"
```
## Tags
`bitrix-env`, `ddns`, `hosts`, `iptables`, `mail`, `mail_alias`, `multisite`, `nginx_status`, `packages`, `passwd`, `php`, `php_modules`, `prompt`, `scripts`, `selinux`

