# memcached
Роль для развёртывания сервиса memcached

Requirements
------------

**gather_subset:** `hardware`

## Variables
```yaml
memcached_service_enable: bool # default: true

memcached_sasl_enable: bool # default: false :Включение аутентификации SASL для memcached
memcached_sasl_user: "string" # default: 'cacheuser'
memcached_sasl_password: "string" # default: 'Clock4bake4aspect'

memcached_config: # default: empty: "" :Конфигурация в /etc/sysconfig/memcached
  port: int # default: 11211
  user: "string" # default: memcached
  maxconn: int # default: 1024
  cachesize: int # units: mb, default: 5% from total RAM size
```
## Tags
`packages` `sasl` `services`

