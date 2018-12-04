# nginx
Роль для развёртывания веб-сервера Nginx (как правило, фронтэнд для php-fpm или httpd). Также ставит TLS-сертификаты для хоста по-умолчанию
## Variables
```yaml
nginx_allow_status_list: # Список IP-адресов, с которых позволено читать страницу статуса Nginx
  - "ipv4"               # default: "127.0.0.0/8"

nginx_http_directives: # Конфигурационные параметры для nginx.conf (контекст http)
  key: value

nginx_main_domain: "fqdn" # Актуальный домен второго уровня, для которого существуют сертификат
                          # и ключ в files, указываемые в двух следующих переменных:
nginx_main_cert: "string"
nginx_main_key: "string"

nginx_example_cert: "string" # Если доменное имя хоста не соотвествует домену nginx_main_domain,
nginx_example_key: "string" # то применяются указанные здесь файлы
```
## Tags
`awstats` `iptables` `logrotate` `nginx` `allow_status` `packages` `scripts` `templates` `tls`

