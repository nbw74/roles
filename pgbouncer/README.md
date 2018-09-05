# pgbouncer

Роль для настройки pgbouncer

### Что эта роль делает

* Настраивает репозиторий pgdg заданной версии
* Устанавливает pgbouncer
* Настраивает его для работы с ролью vhost

## Структура переменных

```yaml
postgresql_version: int[.int] # default: 10

pgbouncer_config:
  idle_transaction_timeout: int # default: 7200

pgbouncer_enable: bool # default: true - Enable pgbouncer service
```
