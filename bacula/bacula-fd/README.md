bacula/bacula-fd
================
Setup Bacula file daemon.
## Variables
```yaml
bacula_ca:
  host: string # e.q. 'bacula-ca.example.com'
  path: string # e.q. '/etc/pki/CA/certs/cacert.pem'
  key_path: string # e.q. '/etc/pki/CA/private/cakey.pem'
  key_pass: string

bacula_fd_csr:
  C: string # e.q. 'RU'
  ST: string # e.q. 'Russian Federation'
  L: string # e.q. 'Moscow'
  O: string # e.q. 'KGB'
  emailAddress: string # e.q. 'sig@kgb.ru'

bacula_dir:
  prefix: string # e.q. 'kgb'
  cn: string # e.q. 'bacula-dir.example.com'
  host: string

bacula_fd:
  prefix: string # default: '{{ inventory_hostname.split('.')[0] }}'
  file_retention: string # Default: '16 months'
  job_retention: string # Default: '16 months'
  pool: string # mutually exclusive with 'pools: { }'
  pools:
    full: string
    differential: string
    incremental: string
```
