# crowd-hpc
Evaluation of a collaborative HPC/AI stack

## Prepare a machine with virtual box and user account

* first get a (virtual) machine with at least 8GB and some disk space
* install virtual box or KVM


For Debian/Ubuntu KVM run:

```
sudo apt install -y qemu-system-x86 libvirt-daemon-system libvirt-clients bridge-utils virtinst

```

and for RHEL9/Rocky9 run 

```
sudo dnf install -y qemu-kvm libvirt virt-install bridge-utils
```


create an new system user account that holds the virtual machines, here this is username `chpc`

```
sudo bash -c 'NEWUSER=chpc && useradd -rm --shell /bin/bash $NEWUSER && loginctl enable-linger $NEWUSER && usermod -aG libvirt,kvm $NEWUSER && su - $NEWUSER'
```



from now on we run every command as user chpc

make sure that systemctl --user will work in that account:

```
echo 'export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}' >> ~/.bashrc
echo 'export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}' >> ~/.bashrc
```

## Clone Repository 

### Contribute back 

if you would like to contribute changes back to crowd-hpc via pull request nor or later do this : 

- Fork the repos from: https://github.com/dirkpetersen/crowd-hpc/fork 
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

## deploy virtual box cluster 

The first step is to install the virtual box cluster. By default we have one gateway (head node) and 3 worker nodes. 

```
./install-vbox-cluster.sh
```

after this done you should see something like this

```
VBoxManage list vms

"gateway-node" {be23c3d8-2c2f-4612-a97a-4de886fd5f2c}
"compute-node-1" {d72f6632-25a5-44bb-920a-b11cf6be2898}
"compute-node-2" {99d292f3-5356-420d-8f10-054689def974}
"compute-node-3" {a67049f9-dca3-4f33-9e1c-b9130f7afe50}
```

if they have not been installed correctly you can delete them

```
for vm in $(VBoxManage list vms | awk '{print $2}' | tr -d '{}'); do
    VBoxManage controlvm "$vm" poweroff
    VBoxManage unregistervm "$vm" --delete
done

VBoxManage natnetwork remove --netname private-net
```