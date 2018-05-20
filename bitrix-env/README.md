<!-- vim: set ft=ansible: -->
# bitrix-env
Роль для развёртывания виртуальной машины с пакетом bitrix-env для CMS "Битрикс"

https://www.1c-bitrix.ru/products/env/

## Variables
```yaml
bx_mail_alias: "string" # default: none :Почтовый алиас для пересылки почты пользователя bitrix

bx_msmtp_host: "string" # default: none :Параметр "host" в msmtprc
bx_msmtp_port: int # default: none :Параметр "port" в msmtprc
bx_msmtp_user: "string" # default: none :Параметр "user" в msmtprc
bx_msmtp_pass: "string" # default: none :Параметр "password" в msmtprc
bx_msmtp_domain: "string" # default: первая и последняя части FQDN

nginx_allow_status_list: # default: <RFC-1918 network list> Список адресов, с которых разрешено
  - "ipv4"               # обращение к странице статуса Nginx

bxvhost:
  db:
    host: "string" # mandatory
    port: "int" # optional; default is '3306'
    name: "string" # mandatory
    pass: "string" # mandatory
  mobile: bool # optional
  redmine:
    title: "string" # mandatory
    description: "string" # mandatory
    id: "string" # optional
  ssh_key_type: "string" # optional, default 'ed25519'

```
## Tags
`bitrix-env` `hosts` `iptables` `mail` `mail_alias` `nginx_status` `packages` `passwd` `php_modules` `prompt` `scripts` `selinux`

