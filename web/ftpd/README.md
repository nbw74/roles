# ftpd

Роль для настройки демона FTP

### Что эта роль делает

* Устанавливает FTP-сервер (в данный момент поддерживается только proftpd)
* Настраивает его для работы за МСЭ (с директивой PassivePorts), опциями TLS и DYNAMIC_BAN_LISTS

## Структура переменных

```yaml
ftpd_variety: proftpd # default
ftpd_enable: bool # default: true

ftpd_config:
  ServerAdmin: string # default: "root@localhost"
  PassivePorts: string # default: "52384 52584"
  TLSRSACertificateFile: string # default: "/etc/pki/tls/certs/proftpd.pem"
  TLSRSACertificateKeyFile: string # default: "/etc/pki/tls/private/proftpd.pem"
```
