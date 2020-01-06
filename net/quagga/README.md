net/quagga
==========
Primitive role for quagga (routing software package) setup. Only **ospfd** is currently supported.
## Variables
```yaml
quagga_daemons:
  - ospfd

quagga_ospfd_config: |
  <block>

quagga_ospfd_restart: bool # default: True;
  # restart ospfd if config changed
```
## Examples
IPIP interface (network-scripts):
```yaml
base_ifcfg:
  - dev: tun0
    variables:
      DEVICE: tun0
      BOOTPROTO: "none"
      ONBOOT: "yes"
      TYPE: IPIP
      TTL: 2
      MULTICAST: "yes"
      MY_OUTER_IPADDR: 192.0.2.10
      MY_INNER_IPADDR: 10.0.0.1
      PEER_OUTER_IPADDR: 198.51.100.20
      PEER_INNER_IPADDR: 10.0.0.2
```
OSPFd configuration:
```yaml
quagga_ospfd_config: |
  interface eth0
  !
  interface lo
  !
  interface tun0
    ip ospf authentication message-digest
    ip ospf dead-interval 8
    ip ospf hello-interval 2
    ip ospf message-digest-key 10 md5 XYZ12345
    ip ospf network point-to-point
  !
  interface eth0
    ip ospf authentication message-digest
    ip ospf dead-interval 8
    ip ospf hello-interval 2
    ip ospf message-digest-key 20 md5 ABC54321
  !
  router ospf
    router-id 192.168.0.1
    passive-interface default
    no passive-interface tun0
    no passive-interface eth0
    network 10.0.0.0/16 area 0.0.0.0
    network 192.168.0.0/24 area 0.0.0.0
    area 0.0.0.0 authentication message-digest
```
