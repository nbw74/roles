# squid
Роль для развёртывания прямого HTTP-прокси squid. Вроде как полностью standalone  и не требует common
## Variables
```yaml
squid_cache_mgr: "email" # default: "admin@localhost" :Администратор кэша

common_ssh_direct_list: # Список адресов с неограниченным доступом к SSHd 
  - "ipv4"              # default: "127.0.0.0/8"

squid_permit_list:      # Список адресов, которым доступен порт squid'а
  - "ipv4"              # default: "127.0.0.0/8"
```
## Tags
`ipset` `iptables` `packages` `squid`

