# crowd-hpc
Evaluation of a collaborative HPC/AI stack

## Prepare a machine with virtual box and user account

* first get a (virtual) machine with at least 8GB and some disk space
* install virtual box or KVM

For Debian/Ubuntu KVM run:

```
sudo apt install -y qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virtinst virtualbmc
# (optional) sudo apt install -y prometheus-libvirt-exporter python3-libvirt python3-virtualbmc
```

and for RHEL9/Rocky9 run 

```
sudo dnf install -y qemu-kvm libvirt virt-install bridge-utils
```

this service is needed for user mode networking

```
sudo systemctl enable libvirtd.service
sudo systemctl restart libvirtd.service
```

create an new system user account that holds the virtual machines, here this is username `chpc`. Note: On RHEL it would be `usermod -aG libvirtd,kvm` instead

```
sudo bash -c 'NEWUSER=chpc && useradd -rm --shell /bin/bash $NEWUSER && loginctl enable-linger $NEWUSER && usermod -aG libvirt,kvm $NEWUSER && su - $NEWUSER'
```

**from now on we run every command as user chpc**

make sure that systemctl --user and virsh user mode will work in that account:

```
echo 'export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}' >> ~/.bashrc
echo 'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}' >> ~/.bashrc
echo 'alias virsh="virsh --connect qemu:///session"' >> ~/.bashrc
source ~/.bashrc
```

## Clone Repository 

Now you need to decide if you might want to contribute back to `crowd-hpc` or not. 

### Contribute back (later)

if you would like to contribute changes back to crowd-hpc via pull request nor or later do this : 

- Fork the repos from: https://github.com/dirkpetersen/crowd-hpc/fork into YOURGITHUB
- add the public key from your VS-code machine to ~/.ssh/authorized_keys
- add the private key for your github account to ~/.ssh/id_ed25519 or similar 

run these commands 

```
git config --global user.email "your.email@address.com"
git config --global user.name "Your Name"
git clone git@github.com:YOURGITHUB/crowd-hpc.git
cd crowd-hpc
```

If you make changes to the code you can commit to your fork (e.g. git add * ; git commit -a -m "your commit message";  git push) and then start a pull request on github.com to contribute back 

### just install - don't contribute 

if you never want to contribute back, simply run this : 

```
git clone https://github.com/dirkpetersen/crowd-hpc.git
cd crowd-hpc
```

## deploy KVM cluster 

The first step is to install a standard KVM cluster. By default we have one gateway (head node) and 3 worker nodes. 

```
./install-kvm-cluster.sh
```


```
virsh 
```