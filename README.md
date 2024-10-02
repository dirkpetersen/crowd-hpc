# crowd-hpc
Evaluation of a collaborative HPC/AI stack in a KVM Sandbox. The Sandbox uses Warewulf4 to deploy a fully functional Slurm cluster, possibly with 4 networks (default, pxe, ipmi, storage)

## Prepare host machine (hypervisor) and user account

* first get a (virtual) machine with at least 8GB memory and a good amount of disk space under /home (last tested with Ubuntu 24.04 and RHEL/Rocky 9.4)

* Run the [prepare-host.sh](https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-host.sh) script as sudo/root user to install packages and configure networking

```
curl https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-host.sh?token=$(date +%s) | sudo bash
```

* Run the [prepare-user.sh](https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-user.sh) script as sudo/root to create a new system user with the right permissions to create VMs (`chpc` in this case)

```
curl -s https://raw.githubusercontent.com/dirkpetersen/crowd-hpc/refs/heads/main/prepare-user.sh?token=$(date +%s) | sudo bash -s -- chpc
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

## deploy KVM cluster 