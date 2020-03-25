ct/docker
=========
Simple role for install docker and run docker containers (optionally)
## Variables
```yaml
docker_daemon_json: { }  # Optionally set options in /etc/docker/daemon.json

docker_containers:  # Optionally run docker containers
  - name: string  # Assign a name to a new container or match an existing container (required).
    image: string  # Repository path and tag used to create the container. 
    published_ports: string  # List of ports to publish from the container to the host.
                             # Use docker CLI syntax: 8000, 9000:8000, or 0.0.0.0:9000:8000,
                             # where 8000 is a container port, 9000 is a host port, and 0.0.0.0 is a host interface.
    volumes: string  # List of volumes to mount within the container.
                     # Use docker CLI-style syntax: /host:/container[:mode]
    restart_policy: string  # no, on-failure, always or unless-stopped (default)
    state: string  # absent, present, stopped or started (default)
```
