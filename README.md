# Kubernetes on Boot2Docker

[![Build Status](https://travis-ci.org/weikinhuang/boot2docker-kubernetes.svg?branch=master)](https://travis-ci.org/weikinhuang/boot2docker-kubernetes)

Run kubernetes on boot2docker using bootkube and docker-in-docker!

This is a simple `docker-compose` configuration to run a kubernetes cluster with an arbitrary number of worker nodes
all within a single dev environment vm running `boot2docker`. This configuration uses a systemd based container that
auto bootstraps a cluster using [`bootkube`](https://github.com/kubernetes-incubator/bootkube) to create a simulated
production setup.

## Requirements

Any operating system that can run the following:

[`docker`](https://docs.docker.com/machine/overview/) 1.12+ that is capable of running a `docker-in-docker` setup, [`boot2docker`](https://github.com/boot2docker/boot2docker) running `aufs` is recommended

[`docker-compose`](https://docs.docker.com/compose/install/) is needed to actually start up the kubernetes cluster

[`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/) must be located somewhere in your `PATH` to access the cluster

## Running

#### Getting started

Getting started after all the components are in place is extremely simple:

```bash
# clone repo
$ git clone https://github.com/weikinhuang/boot2docker-kubernetes
$ cd boot2docker-kubernetes
# start components
$ docker-compose up -d
# watch bootstrap status
$ docker-compose exec master journalctl -f -u bootkube.service
# -- Logs begin at Tue 2017-10-10 01:08:34 UTC. --
# Oct 10 01:08:59 698bb16ca1a0 systemd[1]: Starting Bootkube Kubernetes Bootstrap...
# Oct 10 01:08:59 698bb16ca1a0 boot-k8s.sh[844]: + touch /mnt/share/data/.initialized
# ...
# Oct 10 01:10:14 698bb16ca1a0 boot-k8s.sh[844]: ===== Bootkube deployed successfully =====
# Then ctrl+c to exit command after it's ready
```

#### At this point the cluster should be ready

```bash
$ kubectl get nodes -o wide
NAME           STATUS    ROLES     AGE       VERSION           EXTERNAL-IP   OS-IMAGE                      KERNEL-VERSION       CONTAINER-RUNTIME
406a75bafd18   Ready     <none>    54m       v1.8.0+coreos.0   <none>        Debian GNU/Linux 8 (jessie)   4.4.84-boot2docker   docker://Unknown
698bb16ca1a0   Ready     master    55m       v1.8.0+coreos.0   <none>        Debian GNU/Linux 8 (jessie)   4.4.84-boot2docker   docker://Unknown

$ kubectl get nodes -o custom-columns=DOCKER:.metadata.labels.docker-id,NAME:.metadata.name,INTERNAL-IP:.status.addresses[0].address
DOCKER                           NAME           INTERNAL-IP
boot2dockerkubernetes-node-1     406a75bafd18   172.19.0.4
boot2dockerkubernetes-master-1   698bb16ca1a0   172.19.0.3
```

#### Checking pods status

```bash
$ kubectl get po --all-namespaces  -o wide
NAMESPACE     NAME                                       READY     STATUS    RESTARTS   AGE       IP           NODE
kube-system   calico-node-l6swp                          2/2       Running   0          55m       172.19.0.3   698bb16ca1a0
kube-system   calico-node-w9fcq                          2/2       Running   0          54m       172.19.0.4   406a75bafd18
kube-system   heapster-v1.5.0-beta.0-7f89fb666b-25dst    2/2       Running   0          54m       10.2.0.9     698bb16ca1a0
kube-system   kube-apiserver-kvzgb                       1/1       Running   0          55m       172.19.0.3   698bb16ca1a0
kube-system   kube-controller-manager-6588984cbc-jb5x5   1/1       Running   0          55m       10.2.0.2     698bb16ca1a0
kube-system   kube-controller-manager-6588984cbc-w29mp   1/1       Running   0          55m       10.2.0.4     698bb16ca1a0
kube-system   kube-dns-598c789574-jzsf8                  3/3       Running   0          55m       10.2.0.3     698bb16ca1a0
kube-system   kube-proxy-gzddb                           1/1       Running   0          54m       172.19.0.4   406a75bafd18
kube-system   kube-proxy-xqfrs                           1/1       Running   0          55m       172.19.0.3   698bb16ca1a0
kube-system   kube-scheduler-75d44fdff6-5q4jj            1/1       Running   0          55m       10.2.0.6     698bb16ca1a0
kube-system   kube-scheduler-75d44fdff6-zlczw            1/1       Running   0          55m       10.2.0.5     698bb16ca1a0
kube-system   kubernetes-dashboard-69c5c78645-lsg9g      1/1       Running   0          54m       10.2.1.2     406a75bafd18
kube-system   pod-checkpointer-9v9hs                     1/1       Running   0          55m       172.19.0.3   698bb16ca1a0
kube-system   pod-checkpointer-9v9hs-698bb16ca1a0        1/1       Running   0          55m       172.19.0.3   698bb16ca1a0
```

#### Stopping

```bash
$ docker-compose stop
```

#### Restarting

```bash
$ docker-compose up -d
```

#### Remove cluster

```bash
$ docker-compose down -v
# clean up unnamed volumes that were generated
$ docker volume rm $(docker volume ls -f dangling=true -q)
```

## Configuration

### Exposing ports

TODO: fill in

### Running with a different number of worker nodes

Additional nodes get auto registered

```bash
# run with 0 worker nodes
$ docker-compose up -d --scale node=0

# run with 3 worker nodes
$ docker-compose up -d --scale node=3
```

Nodes can also be scaled via a kubernetes deployment

```bash
# run with 0 worker nodes
$ kubectl scale -n workers --replicas=0 deploy/k8s-worker

# run with 3 worker nodes
$ kubectl scale -n workers --replicas=3 deploy/k8s-worker
```

However when scaling down, nodes must be manually deleted

```bash
$ kubectl delete node [node-hostname]
```

### Bootkube

#### Version

Bootkube version can be specified with an environment variable on the master node's `docker-compose` config.

```yaml
  master:
    environment:
      - BOOTKUBE_IMAGE_URL=quay.io/coreos/bootkube
      - BOOTKUBE_IMAGE_TAG=v0.7.0
```

#### Options

Bootkube can be configured by adding additional environment variables to the master node's `docker-compose` config. Any
environment variables starting with `BOOTKUBE_` is added to the `bootkube render` command's arguments.

```yaml
  master:
    environment:
      - BOOTKUBE_CONF_NETWORK_PROVIDER=--network-provider=experimental-calico
```

#### Using externally generated bootkube assets

This setup can use pre-generated bootkube assets under `./data/assets` automatically, and won't internally generate any
assets. However assets **must** be generated with the following options: `--api-servers=https://master.:6443` and
`--api-server-alt-names` must have a minimum of `DNS=master,DNS=master.`. If the external etcd server (non self-hosted)
is to be used, the flag `--etcd-servers=http://etcd1.:2379` must be specified.

```bash
bootkube render \
    --api-servers=https://master.:6443 \
    --api-server-alt-names=DNS=master,DNS=master. \
    --etcd-servers=http://etcd1.:2379
```

### Kubernetes

#### Version

Kubernetes' hyperkube image can be specified with an environment variable on the node's `docker-compose` config.

```yaml
  node:
    environment:
      - HYPERKUBE_IMAGE_URL=quay.io/coreos/hyperkube
      - HYPERKUBE_IMAGE_TAG=v1.8.0_coreos.0
```

#### `kubelet` options

`kubelet` can be configured by adding additional environment variables to the node's `docker-compose` config. Any
environment variables starting with `KUBELET_ARGS_` is added to the `kubelet` command's arguments.

```yaml
  node:
    environment:
      - KUBELET_ARGS_1=--max-pods=25

  master:
    environment:
      - KUBELET_ARGS_2=--loglevel=2
```

## Speeding up rebuilds

When a cluster is needed to be setup and torn down, exporting images will save a lot of time and bandwidth. Any images
found in `./data/images/all` will be automatically pre-loaded in all node types, images in `./data/images/master` will
only be loaded on the master node, and images in `./data/images/worker` will be loaded only on worker nodes.

Images can be exported by entering the node:

```bash
$ docker-compose exec master bash
# inside the container
$ docker images | tr -s ' ' | cut -f1-2 -d ' ' | tail -n +2 | tr ' ' ':' | xargs -I{} sh -c 'docker save -o "/data/images/all/$(echo "{}" | tr ':' '@' | tr '/' '=').tar" "{}"'
```

## Debugging

#### Checking logs

Check `systemd` logs:

```bash
# Check bootkube logs
$ docker-compose exec master journalctl -f -u bootkube.service

# Check kubelet logs on master node
$ docker-compose exec master journalctl -f -u kubelet.service

# Check kubelet logs on worker node
$ docker-compose exec node journalctl -f -u kubelet.service
```

Entering a container:

```bash
# Enter master node
$ docker-compose exec master bash

# Enter worker node
$ docker-compose exec node bash
```

## Motivation

TODO: fill in

## Related

TODO: fill in
