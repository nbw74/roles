nodejs
======
Very simple role for nodejs installing
## Actions
+ Set up Nodejs rpm repo
+ Install nodejs rpm package
## Variables
```yaml
nodejs_major_version: int # Mandatory
nodejs_yarn_install: bool # default: false
nodejs_nuxt_service: bool # Create nuxt.js systemd instantiated unit
```
## Dependencies
-
