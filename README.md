# crowd-hpc
Evaluation of a collaborative HPC/AI stack

## Prepare a machine with virtual box and user account

* first get a (virtual) machine with at least 8GB and some disk space
* install virtual box, with Ubuntu this is:

```
sudo apt install -y virtualbox
```

create an new system user account that holds the virtual machines, here this is username `chpc`

```
sudo bash -c 'NEWUSER=chpc && useradd -rm --shell /bin/bash $NEWUSER && loginctl enable-linger $NEWUSER && usermod -aG vboxusers $NEWUSER && su - $NEWUSER'
```

from now on we run every command as user chpc

make sure that systemctl --user will work in that account:

```
echo 'export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}' >> ~/.bashrc
echo 'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}' >> ~/.bashrc
```

## deploy virtual box cluster 

clone the repos and run install-vbox-cluster.sh

```
git clone git@github.com:dirkpetersen/crowd-hpc.git
cd crowd-hpc
./install-vbox-cluster.sh
```

