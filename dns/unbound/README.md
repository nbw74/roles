dns/unbound
===========
Simple role for installing the **unbound** -- a validating, recursive, and caching DNS resolver.
## Variables
```yaml
unbound_enable: bool # default: False

unbound_conf: # default: { } # Unbound config options
  interface: [ 'ipv4', 'ipv4@port' ]
  access-control: [ 'CIDR' ]
  num-threads: int # default: 1, dist-default: 4
  local-data: [] # array with 'local-data:' elements (in main file); see full syntax in /etc/unbound/unbound.conf

unbound_local_zones: # default: []
  - name: # e.q. "local"; /etc/unbound/local.d/<name>.conf
    type: string # default: static; see all options in /etc/unbound/unbound.conf
    data: [] # array for 'local-data:' elements (in zone files)
    state: bool # default: true; zone file presence
```
