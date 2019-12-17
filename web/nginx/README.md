# nginx
Роль для развёртывания веб-сервера Nginx (как правило, фронтэнд для php-fpm или httpd). Также ставит TLS-сертификаты для хоста по-умолчанию
## Variables
```yaml
nginx_allow_status_list: # Список IP-адресов, с которых позволено читать страницу статуса Nginx
  - "ipv4"               # default: "127.0.0.0/8"

nginx_certbot:
  email: <e@mail> # мыло для регистрации цертбота

nginx_http_directives: # Конфигурационные параметры для nginx.conf (контекст http)
  key: value
  client_body_timeout: intu # default: '240s'
  client_max_body_size: intu # default: '16m'

nginx_listen_separate: bool # default: True

nginx_self_signed_csr:
  org: Locale Organization
  email: root@localhost
```
## Tags
`awstats` `iptables` `logrotate` `nginx` `allow_status` `packages` `scripts` `templates` `tls`

