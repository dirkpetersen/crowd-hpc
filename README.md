# crowd-hpc
Evaluation of a collaborative HPC/AI stack

## Prepare a machine with virtual box 

* first get a (virtual) machine with at least 8GB and some disk space
* install virtual box, with Ubuntu this is:

```
apt install -y virtualbox
```

create an new system user account that holds the virtual machines 

```
sudo su - 
NEWUSER=crowdhpc && useradd -rm --shell /bin/bash $NEWUSER && loginctl enable-linger $NEWUSER && su - $NEWUSER
```

make sure that systemctl --user will work in that account 

```
echo 'export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}' >> ~/.bashrc
echo 'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}' >> ~/.bashrc
```



