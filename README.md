# PAM

## Задание

1. Запретить всем пользователям, кроме группы **admin** логин в выходные (суббота и воскресенье), без учета праздников.
2. Дать конкретному пользователю права работать с **docker** и возможность рестартить **docker.service**.

## Реализация

Задание сделано на **rockylinux/9** версии **v4.0.0**. Для автоматизации процесса написаны следующие роли **Ansible**, переменные для которых хранятся в [group_vars/all.yml](group_vars/all.yml).

- **groupadd** - создаёт группу **admin**;
- **useradd** - создаёт пользователей **otus** и **otusadm**, а также добавляет пользователей **otusadm**, **root**, **vagrant** в группу **admin**;
- **pam** - устанавливает изменённый скрипт [login.sh](roles/pam/templates/libexec/login.sh) и прописывает его [/etc/pam.d/sshd](roles/pam/templates/sshd). Скрипт изменён так, чтобы он не зависел от локали системы и выводил сообщение `You are not allowed to login on this day of the week!`, если пользователю не разрешено выполнять вход. Для того, чтобы сообщение отображалось в [/etc/pam.d/sshd](roles/pam/templates/sshd) указаны опции **quiet** и  **stdout** для **pam_exec.so**. Чтобы невозможно было подобрать членов группы **admin** с использованием этого модуля, его тип изменён на **account**.
- **docker** - устанавливает **docker**, включает и запускает его сервис;
- **docker_users** - добавляет пользователя **otus** в группу **docker** и разрешает ему останавливать, запускать и перезапускать сервис через правило [docker.rules](roles/docker_users/templates/docker.rules) для **polkit**.

## Запуск

Необходимо скачать **VagrantBox** для **rockylinux/9** версии **v4.0.0** и добавить его в **Vagrant** под именем **rockylinux/9/v4.0.0**. Сделать это можно командами:

```shell
curl -OL https://app.vagrantup.com/rockylinux/boxes/9/versions/4.0.0/providers/virtualbox/amd64/vagrant.box
vagrant box add vagrant.box --name "rockylinux/9/v4.0.0"
rm vagrant.box
```

Для того, чтобы **vagrant 2.3.7** работал с **VirtualBox 7.1.0** необходимо добавить эту версию в **driver_map** в файле **/usr/share/vagrant/gems/gems/vagrant-2.3.7/plugins/providers/virtualbox/driver/meta.rb**:

```ruby
          driver_map   = {
            "4.0" => Version_4_0,
            "4.1" => Version_4_1,
            "4.2" => Version_4_2,
            "4.3" => Version_4_3,
            "5.0" => Version_5_0,
            "5.1" => Version_5_1,
            "5.2" => Version_5_2,
            "6.0" => Version_6_0,
            "6.1" => Version_6_1,
            "7.0" => Version_7_0,
            "7.1" => Version_7_0,
          }
```

После этого нужно сделать **vagrant up**.

Протестировано в **OpenSUSE Tumbleweed**:

- **Vagrant 2.3.7**
- **VirtualBox 7.1.0_SUSE r164728**
- **Ansible 2.17.4**
- **Python 3.11.10**
- **Jinja2 3.1.4**

## Проверка

1. Зайдём на сервер и изменим текущую дату и время на субботу, после чего попробуем подключиться под пользователем **otus** и **otusadm**. Пароли для пользователей можно найти в `passwords/otus.txt` и `passwords/otusadm.txt`:

    ```text
    ❯ vagrant ssh
    Last login: Fri Oct  4 16:22:13 2024 from 10.0.2.2
    [vagrant@pam ~]$ sudo systemctl stop chronyd
    [vagrant@pam ~]$ sudo systemctl stop vboxadd-service.service
    [vagrant@pam ~]$ sudo date -s '20241005'
    Sat Oct  5 12:00:00 AM UTC 2024
    [vagrant@pam ~]$
    logout

    ❯ ssh otus@192.168.56.10
    otus@192.168.56.10's password:
    You are not allowed to login on this day of the week!
    Connection closed by 192.168.56.10 port 22

    ❯ ssh otusadm@192.168.56.10
    otusadm@192.168.56.10's password:
    [otusadm@pam ~]$
    ```

    Как видно при попытки войти под пользователем **otus** в субботу появилось сообщение `You are not allowed to login on this day of the week!`, но не было никаких проблем с входом под пользователем **otusadm**.

2. Перезагрузим машину, чтобы сбросить восстановить дату. Войдём под **otus** и попробуем остановить, запустить, перезапустить сервис **docker**:

    ```text
    ❯ ssh otus@192.168.56.10
    otus@192.168.56.10's password:
    Last failed login: Sat Oct  5 00:00:31 UTC 2024 from 192.168.56.1 on ssh:notty
    There was 1 failed login attempt since the last successful login.
    Last login: Fri Oct  4 16:21:59 2024 from 192.168.56.1
    [otus@pam ~]$ docker ps -a
    CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
    [otus@pam ~]$ systemctl stop docker
    Warning: Stopping docker.service, but it can still be activated by:
      docker.socket
    [otus@pam ~]$ systemctl start docker
    [otus@pam ~]$ systemctl restart docker
    [otus@pam ~]$
    ```

    Все команды выполнились без каких-либо ошибок.
