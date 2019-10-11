systemd-nspawn
==============
## Variables
```yaml
nspawn:
  - name: string # Container name (mandatory). Must be FQDN
    network:
      - Name: <host_if_name> # Default: ansible_default_ipv4.interface
        Address: CIDR # Mandatory (if 'Addresses' is not defined)
        Addresses: # Mandatory (if 'Address' is not defined)
          - Address: CIDR|IPv4
            Peer: IPv4
        Gateway: IPv4 # Optional
        DNS: [ 'IPv4', ... ] # Optional
        State: bool # Configuration presence (default: true)
        Routes:             # Optional static route list for this interface
          - Gateway: IPv4     # Mandatory (Default: undefined)
            Destination: CIDR # Optional (<networkd> default 0.0.0.0/0)
            Source: IPv4|CIDR # Optional (Default: undefined) source prefix of the route
            Metric: uint      # Optional (Default: 600), metric of the route
            Scope: string     # Optional scope of the route, one of "link", "host", "global" (default)
    releasever: 7|8 # Default: ansible_distribution_major_version
    locale: string # Default: en_US.UTF-8
    enabled: bool # Default: true
    mounts:       # Optional
      - mountpoint: string # Mandatory path INSIDE container, will be created
        block_device: string  # Mandatory, will be formatted if needed
        lv:            # Optional dict, create specified LV if defined
          name: string # Mandatory (Default: undefined), new LV name
          vg: string # Mandatory (Default: undefined), VG name for new LV
          size: string # Mandatory (Default: undefined), size in megabytes or optionally with one of [bBsSkKmMgGtTpPeE] units. Note that shrinking in NOT supported!
        fs_type: string         # Optional (Default: ext4)
        fs_opts: string # Optional (Default: undefined), list of options to be passed to mkfs command
        mounted: bool   # Optional (Default: true).
        options: string # Optional, comma separated mount options (Default: defaults)
        owner: string   # Optional (Default: root), owner of mountpoint dir
        group: string   # Optional (Default: root), group of mountpoint dir
        mode: oct       # Optional (Default: 0755), access mode of mountpoint dir

nspawn_if_type:
  <interface_name>: ipvlan|macvlan|bridge # Default: bridge, если интерфейс br\d+, и ipvlan во всех остальных случаях. Этот словарь требуется определять только в сложных сетевых инсталляциях.

nspawn_sshd_ansible: bool # Default: true
```
## Examples
Простейший контейнер:
```yaml
nspawn:
  - name: example.com
    network:
      - Name: enp4s0
        Address: 192.0.2.2/24
        Gateway: 192.0.2.1
        DNS: [ '192.0.2.30' ]
```
Контейнер, каталог /srv которого расположен на SSD-диске:
```yaml
nspawn:
  - name: example.com
    network:
      - Address: 192.0.2.2/24
    mounts:
      - mountpoint: /srv
        block_device: /dev/nvme0n1p3
```
Два адреса на одном интерфейсе:
```yaml
nspawn:
  - name: example.com
    network:
      - Name: enp4s0
        Addresses:
          - Address: 192.0.2.2/24
          - Address: 198.51.100.10/28
        Gateway: 192.0.2.1
        DNS: [ '192.0.2.30', '198.51.100.81' ]
```
Если нужно включить контейнер в приватную сеть -- то создаём мост (linux bridge). В этот мост можно включить сетевой интерфейс сервера (подробнее см. роль `bridge`), а можно оставить список интерфейсов пустым (тогда он будет изолирован от сети хостера). Затем указываем этот мост в качестве одного из интерфейсов контейнера:
```yaml
bridge_devices:
  - dev: br0
    ports: [ enp5s0 ]
    address: 192.0.2.1/24

nspawn:
  - name: example.com
    network:
      - Name: br0
        Address: 192.0.2.2/24
        ...
```
## Advanced networking
Для обеспечения прямой сетевой связности между хостом и контейнерами IP-адрес на хосте должен быть присвоен не физическому интерфейсу (или мосту), а интерфейсу macvlan, созданному поверх физ. интерфейса.
+ Ручное создание интерфейса macvlan
```sh
ip link add link enp5s0 name macvl0 type macvlan mode bridge
ip addr add 203.0.113.1/24 dev macvl0
ip link set up dev macvl0
```
## Variables description
+ `nspawn_if_type:` К каждому интерфейсу хоста (ноды, на которой выполняются контейнеры) можно присоединять интерфейс контейнера либо типа *ipvlan*, либо *macvlan* (но не оба типа вместе). Словарь `nspawn_if_type` определяет тип интерфейсов. В качестве ключа указывается имя интерфейса хоста (например, `eth0` или `eno1`), в качестве значения -- ipvlan, macvlan или bridge. Если этот словарь не определен, то все создаваемые интерфейсы контейнеров будут иметь тип *ipvlan* (или *bridge*, если имя интерфейса совпадает с выражением *br\d+*).

