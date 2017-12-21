---
- hosts: bx.all
  become: yes
  become_method: sudo

  tasks:
  - name: Editing /etc/crontab
    lineinfile:
      dest: "/etc/crontab"
      regexp: '^(.*)cron_events.php }(.*)$'
      line: '\1cron_events.php; }\2'
      backrefs: yes
    notify:
        - restart crond

  handlers:
    - name: restart crond
      service: name=crond state=restarted

### EOF
