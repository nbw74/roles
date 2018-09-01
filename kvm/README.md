kvm
===

Роль для конфигурации хоста qemu-kvm. Управляет пулами хранения, сетью и виртуальными машинами.

Описание структуры данных для host_vars:

```yaml
kvm_accept_existing_disks: bool # (default: false) Не фейлиться, если диск для ВМ уже существует
kvm_common_case: bool # (default: false) Не выполнять таски, специфичные для Southbridge
kvm_leave_hostname: bool # (default: false) Не устанавливать sysprep'ом hostname
kvm_nested: bool # (default: false) Включает поддержку вложенной виртуализации

kvm_pool: # Задаёт storage pool

- name: "cs02" # Имя пула
  type: "logical" # Тип пула (logical|dir)
  path: "/dev/vg00" # Путь к пулу (/dev/vgname в случае "logical", и /file/system/path в случае "dir")
  state: "active" # Состояние пула (active|absent)

kvm_sysprep_root_key: "string" # (optional)

kvm_vm:

- name: "submachine-1" # (mandatory) Имя ВМ
  cpu_count: int # (default: 1) Кол-во виртуальных ЦПУ
  cpu_custom: bool # (default: false) не использовать атрибут host-model для описания гостевого ЦПУ
  disk_bus: "string" # (default: virtio) шина виртуального хранилища (virtio|ide|scsi|sata|usb)
  disk_format: "string" # (default: raw) Формат образа ВМ (raw|qcow2)
  disk_gb: int # (default: 16) Объём образа ВМ, ГБ
  memory_mb: int # (default: 1024) Объём RAM, МБ
  nic_bridge: "string" # (mandatory) Мост на хосте, в который втыкается ВМ
  nic_model: "string" # (default: virtio) модель виртуальной сетевой карты (virtio|e1000|rtl8139)
  pool_name: "string" # (mandatory) Используемый пул хранения
  state: "string" # (default: running) Состояние ВМ (running|shutdown|destroyed|paused)
  sysprep_ifcfg: # (optional) Конфигурация интерфейсов.
    - dev: "eth0" # Имя интерфейса
      bootproto: "static" # Протокол загрузки (static|dhcp)
      address: "198.51.100.10/28" # IP-адрес (для static)
      peer: "198.51.100.1" # Указание peer (для p2p, как в Хетцнере)
      gateway: "198.51.100.1" # Шлюз по-умолчанию
      domain: "string" # Доменное имя для sysprep (по-умолчанию выделяется из ansible_nodename)
  sysprep_root_pass: # (optional) Пароль root
  template_name: "vm_template_c7_sb.qcow2" # (mandatory) Имя файла образа-шаблона

ansible_ssh_proxy_internal_address: "ipaddr" # (default: undefined) Серый адрес сервера,
                                             # выполняющего роль ssh proxy (ProxyCommand)
```
Все подэлементы массива `kvm_vm` (кроме `state`) читаются только при создании ВМ.

Зависимости
-----------
bridge

Лицензия
--------
BSD