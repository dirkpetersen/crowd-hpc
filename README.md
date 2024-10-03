# crowd-hpc
Evaluation of a collaborative HPC/AI stack in a KVM Sandbox. The Sandbox uses Warewulf4 to deploy a fully functional Slurm cluster, possibly with 4 networks (default, pxe, ipmi, storage). While the Warewulf 4 virtual machine uses the latest `Rocky Linux`, the cluster nodes can use `Debian` images/containers such as `Ubuntu` and `Nvidia DGX OS` or and other Redhat like distribution.

## Prepare host machine (hypervisor) and user account

* first get a (virtual) machine with at least 8GB memory and a good amount of disk space under /home (successfully tested with Ubuntu 24.04, RHEL/Rocky 9.4 does current not work, see `Troubleshooting` section below)

* Run the [prepare-host.sh](https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-host.sh) script as sudo/root user to install packages and configure networking

```
curl https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-host.sh?token=$(date +%s) | sudo bash
```

when this is done, you should see this: 

```
Setup completed successfully.
 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   yes         yes
 ipmi      active   yes         yes
 pxe       active   yes         yes
 storage   active   yes         yes
```

* Run the [prepare-user.sh](https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-user.sh) script as sudo/root to create a new system user with the right permissions to create VMs (`chpc` in this case)

```
curl -s https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-user.sh?token=$(date +%s) | sudo bash -s -- chpc
```

when this is done, you should see this: 

```
Creating user chpc...
Enabling linger for chpc...
Configure environment for chpc ...

Enter: sudo su - chpc
```

**from now on we run every command as user, e.g. chpc**

## Clone Repository 

Please decide if you might want to contribute back to `crowd-hpc` on Github 

### Contribute back (now or later)

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

if there are no error messages you should be able see this list of nodes

```
 $ virsh list --all

 Id   Name            State
-------------------------------
 1    control-node    running
 2    worker-node-1   running
 3    worker-node-2   running
 4    worker-node-3   running
```

## Troubleshooting 

if we run ./install-kvm-cluster.sh on Rocky 9.4 we are getting this error: 

```
Creating control node: control-node
Starting control node with virt-install...
ERROR    /usr/libexec/qemu-bridge-helper --use-vnet --br=virbr1 --fd=30: failed to communicate with bridge helper: stderr=access denied by acl file
: Transport endpoint is not connected
Domain installation does not appear to have been successful.
```

Tried :

- `sudo setenforce 0`  # disabled SELinux
- `filecap /usr/libexec/qemu-bridge-helper net_admin` as suggested here: https://bugs.gentoo.org/677152