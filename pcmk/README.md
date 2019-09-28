pcmk
====
Setup Pacemaker + Corosync cluster (w/o resources)
## Variables
```yaml
pcmk_pool: string # Pool name; MANDATORY
pcmk_cluster_name: string # Cluster name; default: CLUSTER-{{ pcmk_pool|upper }}
pcmk_pcsd_restart_daily: bool # default: false
```
## Inventory
```ini
[<pcmk_pool>] ; group with cluster members
node1
node2
; ...
```
## Notes
### Replace failed node
Failed node replacing is not implemented in this role. Do it manually if necessary. (`[c]` - cluster node, `[n]` - new node)
```
[c] ~# pcs cluster node remove --force nodeF
(.. node reinstalling ..)
[n] ~# yum install pcs
[c] ~# pcs cluster auth nodeF
[c] ~# pcs cluster node add nodeF
[n] ~# pcs cluster start
```
## Caveats
### gcp-vpc-move-ip
If you use this module for Virtual IP:
+ Create VM with `--can-ip-forward` option!
+ put JSON auth key in the some file (`/root/key.json` in this example) and execute
```
~# gcloud auth activate-service-account --key-file /root/key.json
```

