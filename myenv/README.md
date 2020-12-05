# myenv
Установка персонализированного окружения пользователя (конфигурация оболочки и редактора)

Requirements
------------

**gather_subset:** `virtual`

## Variables
```yaml
username: "string" # default: "{{ ansible_user }}" :Имя пользователя на удалённой системе, для
                   # которого производится настройка
requiretty: bool # default: true :Если выставлено в false, то выполняются команды, требующие become

addkey: bool # default: false :Если true - на целевую систему устанавливается публичный ключ SSH,
             # (id_rsa.pub), который берётся у пользователя локальной системы, указанного
             # в следующей переменной:
addkey_user: "string" # default: {{ username }}

```
## Examples
При запуске роли вручную удобно указывать переменные следующим образом:
```shell
ansible-playbook myenv.yml -l hostname.tld -e '{ requiretty: false, addkey_user: nbw }'
```

