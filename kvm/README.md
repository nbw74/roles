kvm
===
Роль для конфигурации хоста qemu-kvm.
### Что оно делает
* Настраивает ноду как хост виртуальных машин
* Создаёт пулы хранения
* Скачивает по заданной пользователем ссылке образы-шаблоны виртуальных машин
* Вносит в них изменения посредством `virt-sysprep`
  * Включает serial console с автологином **root** (для использования через `virsh console`)
  * Устанавливает hostname (опционально)
  * Конфигурирует сетевые интерфейсы (опционально)
  * Задаёт пароль **root** (опционально)
  * Интегрирует в образ публичный ключ (опционально)
* Создаёт виртуальные машины с заданными параметрами в заданном пуле
  * Поддерживается только сеть типа *linux bridge*
* Управляет состоянием виртуальных машин (вкл/выкл)
* Удаляет виртуальные машины с их дисками
* Удаляет пулы хранения
### Чего оно не делает
* Не изменяет параметры уже созданных виртуальных машин (кол-во CPU, ОЗУ, объём и кол-во дисков, конфигурацию сетевых интерфейсов и проч.)
## Структура переменных
```yaml
kvm_accept_existing_disks: bool # (default: false) Не фейлиться, если диск для ВМ уже существует

kvm_backup_cron_job:
  - name: "Unique string"
    vmbackup_config:
      vm_list: [] # Mandatory
      remote_host: "string" # Mandatory
      remote_user: "string" # Default: root
      remote_basedir: "path" # Mandatory
      backup_depth: "int" # Default: 3
      backup_method: "shutdown|snapshot" # Default: snapshot
      snapshot_size: "int" # Default: 10; snapshot size in GB
    minute: "string" # Default: *; minute when the job should run ( 0-59, *, */2, etc )
    hour: "string" # Default: *; hour when the job should run ( 0-23, *, */2, etc )
    day: "string" # Default: *; day of the month the job should run ( 1-31, *, */2, etc )
    weekday: "string" # Default: *; day of the week that the job should run ( 0-6 for Sunday-Saturday, *, etc )
    month: "string" # Default: *; month of the year the job should run ( 1-12, *, */2, etc )
    disabled: bool # Default: no; if the job should be disabled (commented out) in the crontab
    state: bool # Default: yes; whether to ensure the job is present or absent

kvm_common_case: bool # (default: false) Не выполнять таски, специфичные для Southbridge
kvm_leave_hostname: bool # (default: false) Не устанавливать sysprep'ом hostname
kvm_mac_printout: bool # (default: false)
kvm_nested: bool # (default: false) Включает поддержку вложенной виртуализации

kvm_pool: # Задаёт storage pool

- name: "string" # Имя пула; при типе logical должно совпадать с именем VG
  type: "string" # Тип пула (logical|dir)
  path: "string" # Путь к пулу (/dev/vgname в случае "logical", и /file/system/path в случае "dir")
  state: "string" # Состояние пула (active|absent)

kvm_sysprep_root_key: "string" # (optional) Ключ SSH, который можно интегрировать
                               # суперпользователю в ВМ
kvm_template_default: "string"  # Имя образа-шаблона по-умолчанию
kvm_templates_uri: "uri" # (mandatory) URI, откуда скачивать шаблоны

kvm_vm:

- name: "string" # (mandatory) Имя ВМ
  nic_bridge: "string" # (mandatory) Мост на хосте, в который втыкается ВМ
  pool_name: "string" # (mandatory) Используемый пул хранения
  template_name: "string" # (default: kvm_template_default; mandatory if not set) Имя образа-шаблона
  cpu_count: int # (default: 1) Кол-во виртуальных ЦПУ
  cpu_custom: bool # (default: false) не использовать атрибут host-model для описания гостевого ЦПУ
  disk_bus: "string" # (default: virtio) шина виртуального хранилища (virtio|ide|scsi|sata|usb)
  disk_format: "string" # (default: raw) Формат образа ВМ (raw|qcow2)
  disk_gb: int # (default: 16) Объём образа ВМ, ГБ
  memory_mb: int # (default: 1024) Объём RAM, МБ
  nic_model: "string" # (default: virtio) модель виртуальной сетевой карты (virtio|e1000|rtl8139)
  state: "string" # (default: running) Состояние ВМ (running|shutdown|destroyed|paused|undefined);
                  # undefined полностью удаляет ВМ с первым диском
  sysprep_domain: "string" # (default: from ansible_nodename) Доменное имя для sysprep
  sysprep_hostname: "string" # (default: name) Имя хоста для sysprep
  sysprep_ifcfg: # (optional) Конфигурация интерфейсов.
    - dev: "string" # Имя интерфейса (например, eth0)
      bootproto: "string" # (default: "none") Протокол загрузки (none|dhcp)
      address: "ipv4/prefix" # IP-адрес (для static)
      peer: "ipv4" # Указание peer (для p2p, как в Хетцнере)
      gateway: "ipv4" # Шлюз по-умолчанию
  sysprep_root_pass: "string" # (optional) Пароль root
  template_name: "string" # (mandatory) Имя файла образа-шаблона

ansible_ssh_proxy_internal_address: "ipv4" # (default: undefined) Серый адрес сервера,
                                           # выполняющего роль ssh proxy (ProxyCommand)
```
Все элементы словарей в списке `kvm_vm` (кроме `name` и `state`) читаются только при создании ВМ.
## Пример
#### Типовая кофигурация сервера с внутренней приватной сетью и виртуальной машиной за NAT, образ на LVM
```yaml
roles:
  - [...]
  - kvm
  - bridge
  - nat

bridge_devices:
  - dev: br1
    address: 192.168.100.1/24
    ports: []

nat_network: 192.168.100.0/24
ansible_ssh_proxy_internal_address: 192.168.100.1
kvm_template_default: vm_template_c7_sb_2.qcow2

kvm_pool:
  - name: images
    type: dir
    path: /var/lib/libvirt/images

  - name: main
    type: logical
    path: /dev/main

kvm_vm:
  - name: example.com
    memory_mb: 2048
    nic_bridge: br1
    pool_name: main
    disk_gb: 40
    cpu_count: 2
    sysprep_ifcfg:
      - dev: eth0
        address: 192.168.100.10/24
        gateway: 192.168.100.1
```
## Зависимости
bridge
## Лицензия
BSD
