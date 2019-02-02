# Kubernetes with Istio demo

[![Build Status](https://travis-ci.com/ruzickap/k8s-istio-demo.svg?branch=master)](https://travis-ci.com/ruzickap/k8s-istio-demo)

[GitBook version](https://ruzickap.gitbook.io/k8s-istio-demo/)

Find below few commands showing basics of Istio...

## Requirements

* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (kubernetes-client package)
* [Helm](https://helm.sh/)
* [Siege](https://github.com/JoeDog/siege) (siege package)
* [Terraform](https://www.terraform.io/)

or just

* [Docker](https://www.docker.com/)

## Install Kubernetes to Opnestack VMs

The following sections will create VMs in openstack and install k8s into them.

### Prepare the working environment inside Docker

You can skip this part if you have [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), [Helm](https://helm.sh/), [Siege](https://github.com/JoeDog/siege) and [Terraform](https://www.terraform.io/) installed.

Run Ubuntu docker image and mount the directory there:

```bash
docker run -it -rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v $PWD:/mnt ubuntu
```

Install necessary software into the docker container:

```bash
apt update
apt install -y apt-transport-https curl firefox git gnupg jq openssh-client siege unzip vim
```

Install kubernetes-client package (kubectl):

```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl
```

Install Terraform...

```bash
TERRAFORM_LATEST_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')
curl --silent --location https://releases.hashicorp.com/terraform/${TERRAFORM_LATEST_VERSION}/terraform_${TERRAFORM_LATEST_VERSION}_linux_amd64.zip --output /tmp/terraform_linux_amd64.zip
unzip -o /tmp/terraform_linux_amd64.zip -d /usr/local/bin/
```

Change directory to `/mnt` where the git repository is mounted:

```bash
cd /mnt
```

### Provision VMs in OpenStack

Start 3 VMs (one master and 2 workers) where the k8s will be installed.

Generate ssh keys if not exists:

```bash
test -f $HOME/.ssh/id_rsa || ( install -m 0700 -d $HOME/.ssh && ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -q -N "" )
# ssh-agent must be running...
test -n "$SSH_AUTH_SOCK" || eval `ssh-agent`
ssh-add
```

Clone this git repository:

```bash
git clone https://github.com/ruzickap/k8s-istio-demo
cd k8s-istio-demo
```

Modify the terraform variable file if needed:

```bash
cat > terrafrom/openstack/terraform.tfvars << EOF
openstack_auth_url                                 = "https://ic-us.ssl.mirantis.net:5000/v3"
openstack_instance_flavor_name                     = "compact.dbs"
openstack_instance_image_name                      = "bionic-server-cloudimg-amd64-20190119"
openstack_networking_subnet_dns_nameservers        = ["172.19.80.70"]
openstack_password                                 = "password"
openstack_tenant_name                              = "mirantis-services-team"
openstack_user_name                                = "pruzicka"
openstack_user_domain_name                         = "ldap_mirantis"
prefix                                             = "pruzicka-k8s-istio-demo"
EOF
```

Download terraform components:

```bash
terraform init -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
```

Create VMs in OpenStack:

```bash
terraform apply -auto-approve -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
```

Show terraform output:

```bash
terraform output
```

Output:

```shell
vms_name = [
    pruzicka-k8s-istio-demo-node01.01.localdomain,
    pruzicka-k8s-istio-demo-node02.01.localdomain,
    pruzicka-k8s-istio-demo-node03.01.localdomain
]
vms_public_ip = [
    172.16.240.185,
    172.16.242.218,
    172.16.240.44
]
```

At the end of the output you should see 3 IP addresses which should be accessible by ssh using your public key (`~/.ssh/id_rsa.pub`).

### Install k8s

Install k8s using kubeadm to the provisioned VMs:

```bash
./install-k8s-kubeadm.sh
```

Check if all nodes are up:

```bash
export KUBECONFIG=$PWD/kubeconfig.conf
kubectl get nodes -o wide
```

Output:

```shell
NAME                             STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
pruzicka-k8s-istio-demo-node01   Ready     master    2m        v1.13.2   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://18.6.1
pruzicka-k8s-istio-demo-node02   Ready     <none>    1m        v1.13.2   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://18.6.1
pruzicka-k8s-istio-demo-node03   Ready     <none>    1m        v1.13.2   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://18.6.1
```

View services, deployments, and pods:

``` bash
kubectl get svc,deploy,po --all-namespaces -o wide
```

Output:

```shell
NAMESPACE     NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE       SELECTOR
default       service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP         2m        <none>
kube-system   service/kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   2m        k8s-app=kube-dns

NAMESPACE     NAME                            DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS   IMAGES                     SELECTOR
kube-system   deployment.extensions/coredns   2         2         2            2           2m        coredns      k8s.gcr.io/coredns:1.2.6   k8s-app=kube-dns

NAMESPACE     NAME                                                         READY     STATUS    RESTARTS   AGE       IP               NODE
kube-system   pod/coredns-86c58d9df4-fs74t                                 1/1       Running   0          2m        10.244.0.2       pruzicka-k8s-istio-demo-node01
kube-system   pod/coredns-86c58d9df4-l5gqx                                 1/1       Running   0          2m        10.244.0.3       pruzicka-k8s-istio-demo-node01
kube-system   pod/etcd-pruzicka-k8s-istio-demo-node01                      1/1       Running   0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-apiserver-pruzicka-k8s-istio-demo-node01            1/1       Running   0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-controller-manager-pruzicka-k8s-istio-demo-node01   1/1       Running   0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-flannel-ds-amd64-22rf7                              1/1       Running   0          1m        192.168.250.12   pruzicka-k8s-istio-demo-node02
kube-system   pod/kube-flannel-ds-amd64-fx62c                              1/1       Running   0          2m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-flannel-ds-amd64-kws99                              1/1       Running   0          1m        192.168.250.13   pruzicka-k8s-istio-demo-node03
kube-system   pod/kube-proxy-8vfm2                                         1/1       Running   0          1m        192.168.250.13   pruzicka-k8s-istio-demo-node03
kube-system   pod/kube-proxy-qmtvr                                         1/1       Running   0          1m        192.168.250.12   pruzicka-k8s-istio-demo-node02
kube-system   pod/kube-proxy-r8hj8                                         1/1       Running   0          2m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-scheduler-pruzicka-k8s-istio-demo-node01            1/1       Running   0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
```

## Use Minikube

Install Minikube if needed: [https://kubernetes.io/docs/tasks/tools/install-minikube/](https://kubernetes.io/docs/tasks/tools/install-minikube/)

Start minikube

```bash
KUBERNETES_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | tr -d v)
sudo minikube start --vm-driver=none --bootstrapper=kubeadm --kubernetes-version=v${KUBERNETES_VERSION}
```

Install kubernetes-client package (kubectl):

```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl socat
```

## Install Helm

Install Helm binary locally:

```bash
curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash
```

Install Tiller (the Helm server-side component) into the Kubernetes Cluster:

```bash
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --wait --service-account tiller
helm repo update
```

Check if the tiller was installed properly:

```bash
kubectl get pods -l app=helm --all-namespaces
```

Output:

```shell
NAMESPACE     NAME                            READY     STATUS    RESTARTS   AGE
kube-system   tiller-deploy-dbb85cb99-hhxrt   1/1       Running   0          35s
```

## Instal Rook

Install Rook Operator (Ceph storage for k8s):

```bash
helm repo add rook-stable https://charts.rook.io/stable
helm install --wait --name rook-ceph --namespace rook-ceph-system rook-stable/rook-ceph
sleep 10
```

See how the rook-ceph-system should look like:

```bash
kubectl get svc,deploy,po --namespace=rook-ceph-system -o wide
```

Output:

```shell
NAME                                       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS           IMAGES             SELECTOR
deployment.extensions/rook-ceph-operator   1         1         1            1           2m        rook-ceph-operator   rook/ceph:v0.9.2   app=rook-ceph-operator

NAME                                      READY     STATUS    RESTARTS   AGE       IP               NODE
pod/rook-ceph-agent-7kkdn                 1/1       Running   0          1m        192.168.250.13   pruzicka-k8s-istio-demo-node03
pod/rook-ceph-agent-bbkvn                 1/1       Running   0          1m        192.168.250.12   pruzicka-k8s-istio-demo-node02
pod/rook-ceph-agent-mlbpf                 1/1       Running   0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
pod/rook-ceph-operator-7478c899b5-bpvt7   1/1       Running   0          2m        10.244.2.2       pruzicka-k8s-istio-demo-node03
pod/rook-discover-58bfz                   1/1       Running   0          1m        10.244.0.4       pruzicka-k8s-istio-demo-node01
pod/rook-discover-mhbgb                   1/1       Running   0          1m        10.244.2.3       pruzicka-k8s-istio-demo-node03
pod/rook-discover-ndblh                   1/1       Running   0          1m        10.244.1.3       pruzicka-k8s-istio-demo-node02
```

Create your Rook cluster:

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml
sleep 50
```

Get the Toolbox with ceph commands:

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/toolbox.yaml
sleep 250
```

Check what was created in `rook-ceph` namespace:

```bash
kubectl get svc,deploy,po --namespace=rook-ceph -o wide
```

Output:

```shell
TODO xxxxxxxxx
```

Create a storage class based on the Ceph RBD volume plugin:

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/storageclass.yaml
# Give Ceph some time to create pool...
sleep 10
```

Set `rook-ceph-block` as default Storage Class:

```bash
kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Check the Storage Classes:

```bash
kubectl describe storageclass
```

Output:

```shell
Name:                  rook-ceph-block
IsDefaultClass:        Yes
Annotations:           storageclass.kubernetes.io/is-default-class=true
Provisioner:           ceph.rook.io/block
Parameters:            blockPool=replicapool,clusterNamespace=rook-ceph,fstype=xfs
AllowVolumeExpansion:  <unset>
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     Immediate
Events:                <none>
```

See the CephBlockPool:

```bash
kubectl describe cephblockpool --namespace=rook-ceph
```

Output:

```shell
Name:         replicapool
Namespace:    rook-ceph
Labels:       <none>
Annotations:  <none>
API Version:  ceph.rook.io/v1
Kind:         CephBlockPool
Metadata:
  Creation Timestamp:  2019-01-29T09:48:18Z
  Generation:          1
  Resource Version:    2160
  Self Link:           /apis/ceph.rook.io/v1/namespaces/rook-ceph/cephblockpools/replicapool
  UID:                 01ce3c4d-23ab-11e9-8a8d-fa163e64621e
Spec:
  Replicated:
    Size:  1
Events:    <none>
```

Check the status of your Ceph installation:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph status
```

Output:

```shell
  cluster:
    id:     e8a42625-f69c-441f-9895-21a19615da54
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum c,b,a
    mgr: a(active)
    osd: 3 osds: 3 up, 3 in

  data:
    pools:   1 pools, 100 pgs
    objects: 0  objects, 0 B
    usage:   13 GiB used, 44 GiB / 58 GiB avail
    pgs:     100 active+clean
```

Ceph status:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd status
```

Output:

```shell
+----+--------------------------------+-------+-------+--------+---------+--------+---------+-----------+
| id |              host              |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+--------------------------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | pruzicka-k8s-istio-demo-node02 | 4437M | 14.8G |    0   |     0   |    0   |     0   | exists,up |
| 1  | pruzicka-k8s-istio-demo-node01 | 4931M | 14.3G |    0   |     0   |    0   |     0   | exists,up |
| 2  | pruzicka-k8s-istio-demo-node03 | 4285M | 15.0G |    0   |     0   |    0   |     0   | exists,up |
+----+--------------------------------+-------+-------+--------+---------+--------+---------+-----------+
```

Check health of Ceph cluster:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph health detail
```

Output:

```shell
HEALTH_OK
```

Check monitor quorum status of Ceph:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph quorum_status --format json-pretty
```

Dump monitoring information from Ceph:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph mon dump
```

Output:

```shell
epoch 3
fsid e8a42625-f69c-441f-9895-21a19615da54
last_changed 2019-01-29 09:45:03.380133
created 2019-01-29 09:43:53.046981
0: 10.96.51.185:6790/0 mon.c
1: 10.103.75.150:6790/0 mon.b
2: 10.109.40.168:6790/0 mon.a
dumped monmap epoch 3
```

Check the cluster usage status:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph df
```

Output:

```shell
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED
    58 GiB     44 GiB       13 GiB         23.13
POOLS:
    NAME            ID     USED     %USED     MAX AVAIL     OBJECTS
    replicapool     1       0 B         0        40 GiB           0
```

Check OSD usage of Ceph:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd df
```

Output:

```shell
ID CLASS WEIGHT  REWEIGHT SIZE   USE     AVAIL  %USE  VAR  PGS
 1   hdd 0.01880  1.00000 19 GiB 4.8 GiB 14 GiB 25.07 1.08  32
 0   hdd 0.01880  1.00000 19 GiB 4.3 GiB 15 GiB 22.56 0.97  32
 2   hdd 0.01880  1.00000 19 GiB 4.2 GiB 15 GiB 21.78 0.94  36
                    TOTAL 58 GiB  13 GiB 44 GiB 23.13
MIN/MAX VAR: 0.94/1.08  STDDEV: 1.40
```

Check the Ceph monitor:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph mon stat
```

Output:

```shell
e3: 3 mons at {a=10.109.40.168:6790/0,b=10.103.75.150:6790/0,c=10.96.51.185:6790/0}, election epoch 16, leader 0 c, quorum 0,1,2 c,b,a
```

Check OSD stats:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd stat
```

Output:

```shell
3 osds: 3 up, 3 in; epoch: e20
```

Check pool stats:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd pool stats
```

Output:

```shell
pool replicapool id 1
  nothing is going on
```

Check pg stats:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph pg stat
```

Output:

```shell
100 pgs: 100 active+clean; 0 B data, 13 GiB used, 44 GiB / 58 GiB avail
```

List the Ceph pools in detail:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd pool ls detail
```

Output:

```shell
pool 1 'replicapool' replicated size 1 min_size 1 crush_rule 1 object_hash rjenkins pg_num 100 pgp_num 100 last_change 20 flags hashpspool stripe_width 0 application rbd
```

Check the CRUSH map view of OSDs:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd tree
```

Output:

```shell
ID CLASS WEIGHT  TYPE NAME                               STATUS REWEIGHT PRI-AFF
-1       0.05640 root default
-3       0.01880     host pruzicka-k8s-istio-demo-node01
 1   hdd 0.01880         osd.1                               up  1.00000 1.00000
-2       0.01880     host pruzicka-k8s-istio-demo-node02
 0   hdd 0.01880         osd.0                               up  1.00000 1.00000
-4       0.01880     host pruzicka-k8s-istio-demo-node03
 2   hdd 0.01880         osd.2                               up  1.00000 1.00000
```

List the cluster authentication keys:

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph auth list
```

## Install ElasticSearch, Kibana, Fluentbit

Add ElasticSearch operator to Helm:

```bash
helm repo add es-operator https://raw.githubusercontent.com/upmc-enterprises/elasticsearch-operator/master/charts/
```

Install ElasticSearch operator:

```bash
helm install --wait --name elasticsearch-operator es-operator/elasticsearch-operator --set rbac.enabled=True --namespace es-operator
sleep 50
```

Check how the operator looks like:

```bash
kubectl get svc,deploy,po --namespace=es-operator -o wide
```

Output:

```shell
NAME                                           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS               IMAGES                                          SELECTOR
deployment.extensions/elasticsearch-operator   1         1         1            0           32s       elasticsearch-operator   upmcenterprises/elasticsearch-operator:0.0.12   name=elasticsearch-operator,release=elasticsearch-operator

NAME                                          READY     STATUS    RESTARTS   AGE       IP           NODE
pod/elasticsearch-operator-5dc59b8cc5-hq9hg   0/1       Running   0          32s       10.244.2.8   pruzicka-k8s-istio-demo-node03
```

Install ElasticSearch cluster:

```bash
helm install --wait --name=elasticsearch --namespace logging es-operator/elasticsearch \
  --set kibana.enabled=true \
  --set cerebro.enabled=true \
  --set storage.class=rook-ceph-block \
  --set clientReplicas=1,masterReplicas=1,dataReplicas=1
sleep 500
```

Show ElasticSearch components:

```bash
kubectl get svc,deploy,po,pvc --namespace=logging -o wide
```

Output:

```shell
NAME                                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
service/cerebro-elasticsearch-cluster                   ClusterIP   10.108.166.166   <none>        80/TCP     6m        role=cerebro
service/elasticsearch-discovery-elasticsearch-cluster   ClusterIP   10.106.183.114   <none>        9300/TCP   6m        component=elasticsearch-elasticsearch-cluster,role=master
service/elasticsearch-elasticsearch-cluster             ClusterIP   10.100.7.189     <none>        9200/TCP   6m        component=elasticsearch-elasticsearch-cluster,role=client
service/es-data-svc-elasticsearch-cluster               ClusterIP   10.107.68.98     <none>        9300/TCP   6m        component=elasticsearch-elasticsearch-cluster,role=data
service/kibana-elasticsearch-cluster                    ClusterIP   10.96.44.25      <none>        80/TCP     6m        role=kibana

NAME                                                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS                        IMAGES                                                    SELECTOR
deployment.extensions/cerebro-elasticsearch-cluster     1         1         1            1           6m        cerebro-elasticsearch-cluster     upmcenterprises/cerebro:0.6.8                             component=elasticsearch-elasticsearch-cluster,name=cerebro-elasticsearch-cluster,role=cerebro
deployment.extensions/es-client-elasticsearch-cluster   3         3         3            3           6m        es-client-elasticsearch-cluster   upmcenterprises/docker-elasticsearch-kubernetes:6.1.3_0   cluster=elasticsearch-cluster,component=elasticsearch-elasticsearch-cluster,name=es-client-elasticsearch-cluster,role=client
deployment.extensions/kibana-elasticsearch-cluster      1         1         1            1           6m        kibana-elasticsearch-cluster      docker.elastic.co/kibana/kibana-oss:6.1.3                 component=elasticsearch-elasticsearch-cluster,name=kibana-elasticsearch-cluster,role=kibana

NAME                                                    READY     STATUS    RESTARTS   AGE       IP            NODE
pod/cerebro-elasticsearch-cluster-64888cf977-8cj5q      1/1       Running   0          6m        10.244.1.11   pruzicka-k8s-istio-demo-node02
pod/es-client-elasticsearch-cluster-8d9df64b7-4684l     1/1       Running   0          6m        10.244.2.10   pruzicka-k8s-istio-demo-node03
pod/es-client-elasticsearch-cluster-8d9df64b7-dfcpx     1/1       Running   0          6m        10.244.0.9    pruzicka-k8s-istio-demo-node01
pod/es-client-elasticsearch-cluster-8d9df64b7-tpm55     1/1       Running   0          6m        10.244.1.10   pruzicka-k8s-istio-demo-node02
pod/es-data-elasticsearch-cluster-rook-ceph-block-0     1/1       Running   0          6m        10.244.1.12   pruzicka-k8s-istio-demo-node02
pod/es-data-elasticsearch-cluster-rook-ceph-block-1     1/1       Running   0          3m        10.244.0.10   pruzicka-k8s-istio-demo-node01
pod/es-data-elasticsearch-cluster-rook-ceph-block-2     1/1       Running   0          3m        10.244.2.13   pruzicka-k8s-istio-demo-node03
pod/es-master-elasticsearch-cluster-rook-ceph-block-0   1/1       Running   0          6m        10.244.2.12   pruzicka-k8s-istio-demo-node03
pod/es-master-elasticsearch-cluster-rook-ceph-block-1   1/1       Running   0          1m        10.244.1.13   pruzicka-k8s-istio-demo-node02
pod/es-master-elasticsearch-cluster-rook-ceph-block-2   1/1       Running   0          1m        10.244.0.11   pruzicka-k8s-istio-demo-node01
pod/kibana-elasticsearch-cluster-7fb7f88f55-xk76r       1/1       Running   0          6m        10.244.2.11   pruzicka-k8s-istio-demo-node03

NAME                                                                              STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
persistentvolumeclaim/es-data-es-data-elasticsearch-cluster-rook-ceph-block-0     Bound     pvc-c4e4e5ef-23ab-11e9-8a8d-fa163e64621e   1Gi        RWO            rook-ceph-block   6m
persistentvolumeclaim/es-data-es-data-elasticsearch-cluster-rook-ceph-block-1     Bound     pvc-1c1a3b14-23ac-11e9-8a8d-fa163e64621e   1Gi        RWO            rook-ceph-block   3m
persistentvolumeclaim/es-data-es-data-elasticsearch-cluster-rook-ceph-block-2     Bound     pvc-393aabf9-23ac-11e9-8a8d-fa163e64621e   1Gi        RWO            rook-ceph-block   3m
persistentvolumeclaim/es-data-es-master-elasticsearch-cluster-rook-ceph-block-0   Bound     pvc-c4c97a1a-23ab-11e9-8a8d-fa163e64621e   1Gi        RWO            rook-ceph-block   6m
persistentvolumeclaim/es-data-es-master-elasticsearch-cluster-rook-ceph-block-1   Bound     pvc-731f9ca5-23ac-11e9-8a8d-fa163e64621e   1Gi        RWO            rook-ceph-block   1m
persistentvolumeclaim/es-data-es-master-elasticsearch-cluster-rook-ceph-block-2   Bound     pvc-82448ea7-23ac-11e9-8a8d-fa163e64621e   1Gi        RWO            rook-ceph-block   1m
```

List provisioned ElasticSearch clusters:

```bash
kubectl get elasticsearchclusters --all-namespaces
```

Output:

```shell
NAMESPACE   NAME                    AGE
logging     elasticsearch-cluster   7m
```

Install Fluentbit:

```bash
helm install --wait stable/fluent-bit --name=fluent-bit --namespace=logging \
  --set metrics.enabled=true \
  --set backend.type=es \
  --set backend.es.host=elasticsearch-elasticsearch-cluster \
  --set backend.es.tls=on \
  --set backend.es.tls_verify=off
```

Configure port forwarding for Kibana:

```bash
# Kibana UI - https://localhost:5601
kubectl -n logging port-forward $(kubectl -n logging get pod -l role=kibana -o jsonpath='{.items[0].metadata.name}') 5601:5601 &
```

Configure ElasticSearch:

* Navigate to the [Kibana UI](https://localhost:5601) and click the "Set up index patterns" in the top right.
* Use * as the index pattern, and click "Next step.".
* Select @timestamp as the Time Filter field name, and click "Create index pattern."

Check fluent-bit installation:

```bash
kubectl get -l app=fluent-bit svc,pods --all-namespaces -o wide
```

Output:

```shell
NAMESPACE   NAME                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
logging     service/fluent-bit-fluent-bit-metrics   ClusterIP   10.110.236.121   <none>        2020/TCP   7h        app=fluent-bit,release=fluent-bit

NAMESPACE   NAME                              READY     STATUS    RESTARTS   AGE       IP            NODE
logging     pod/fluent-bit-fluent-bit-dcg4s   1/1       Running   0          7h        10.244.1.15   pruzicka-k8s-istio-demo-node03
logging     pod/fluent-bit-fluent-bit-tfqdb   1/1       Running   0          7h        10.244.0.11   pruzicka-k8s-istio-demo-node01
logging     pod/fluent-bit-fluent-bit-tnxj2   1/1       Running   0          7h        10.244.2.13   pruzicka-k8s-istio-demo-node02
```

## Istio Architecture

Few notes about Istio architecture...

![Istio Architecture](https://istio.io/docs/concepts/what-is-istio/arch.svg)

* [Envoy](https://istio.io/docs/concepts/what-is-istio/#envoy) - is a high-performance proxy to mediate all inbound and outbound traffic for all services in the service mesh.
* [Mixer](https://istio.io/docs/concepts/what-is-istio/#mixer) - enforces access control and usage policies across the service mesh, and collects telemetry data from the Envoy proxy and other services.
* [Pilot](https://istio.io/docs/concepts/what-is-istio/#pilot) - provides service discovery for the Envoy sidecars, traffic management capabilities for intelligent routing.
* [Citadel](https://istio.io/docs/concepts/what-is-istio/#citadel) - provides strong service-to-service and end-user authentication with built-in identity and credential management.

![Traffic Management with Istio](https://istio.io/docs/concepts/traffic-management/TrafficManagementOverview.svg)

![Istio Security Architecture](https://istio.io/docs/concepts/security/architecture.svg)

### Istio types

* [VirtualService](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#VirtualService) defines the rules that control how requests for a service are routed within an Istio service mesh.
* [DestinationRule](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#DestinationRule) configures the set of policies to be applied to a request after VirtualService routing has occurred.
* [ServiceEntry](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#ServiceEntry) is commonly used to enable requests to services outside of an Istio service mesh.
* [Gateway](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#Gateway) configures a load balancer for HTTP/TCP traffic, most commonly operating at the edge of the mesh to enable ingress traffic for an application.

## Install Istio

Either download Istio directly from [https://github.com/istio/istio/releases](https://github.com/istio/istio/releases) or get the latest version by using curl:

```bash
test -d files || mkdir files
cd files
curl -sL https://git.io/getLatestIstio | sh -
```

Change the directory to the Istio installation files location:

```bash
cd istio*
```

Install Istio using Helm:

```bash
helm install --wait --name istio --namespace istio-system install/kubernetes/helm/istio \
  --set gateways.istio-ingressgateway.type=NodePort \
  --set gateways.istio-egressgateway.type=NodePort \
  --set grafana.enabled=true \
  --set kiali.enabled=true \
  --set kiali.dashboard.grafanaURL=http://localhost:3000 \
  --set kiali.dashboard.jaegerURL=http://localhost:16686 \
  --set servicegraph.enabled=true \
  --set telemetry-gateway.grafanaEnabled=true \
  --set telemetry-gateway.prometheusEnabled=true \
  --set tracing.enabled=true
```

See the Istio components:

```bash
kubectl get --namespace=istio-system svc,deployment,pods -o wide
```

Output:

```shell
NAME                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                                                                   AGE       SELECTOR
service/grafana                  ClusterIP   10.106.150.213   <none>        3000/TCP                                                                                                                  12m       app=grafana
service/istio-citadel            ClusterIP   10.96.179.146    <none>        8060/TCP,9093/TCP                                                                                                         12m       istio=citadel
service/istio-egressgateway      NodePort    10.103.222.60    <none>        80:32096/TCP,443:31941/TCP                                                                                                12m       app=istio-egressgateway,istio=egressgateway
service/istio-galley             ClusterIP   10.96.254.151    <none>        443/TCP,9093/TCP                                                                                                          12m       istio=galley
service/istio-ingressgateway     NodePort    10.110.96.100    <none>        80:31380/TCP,443:31390/TCP,31400:31400/TCP,15011:30425/TCP,8060:31127/TCP,853:32621/TCP,15030:30835/TCP,15031:32123/TCP   12m       app=istio-ingressgateway,istio=ingressgateway
service/istio-pilot              ClusterIP   10.110.95.231    <none>        15010/TCP,15011/TCP,8080/TCP,9093/TCP                                                                                     12m       istio=pilot
service/istio-policy             ClusterIP   10.106.16.125    <none>        9091/TCP,15004/TCP,9093/TCP                                                                                               12m       istio-mixer-type=policy,istio=mixer
service/istio-sidecar-injector   ClusterIP   10.104.200.156   <none>        443/TCP                                                                                                                   12m       istio=sidecar-injector
service/istio-telemetry          ClusterIP   10.101.139.163   <none>        9091/TCP,15004/TCP,9093/TCP,42422/TCP                                                                                     12m       istio-mixer-type=telemetry,istio=mixer
service/jaeger-agent             ClusterIP   None             <none>        5775/UDP,6831/UDP,6832/UDP                                                                                                12m       app=jaeger
service/jaeger-collector         ClusterIP   10.100.202.77    <none>        14267/TCP,14268/TCP                                                                                                       12m       app=jaeger
service/jaeger-query             ClusterIP   10.110.237.230   <none>        16686/TCP                                                                                                                 12m       app=jaeger
service/kiali                    ClusterIP   10.110.159.171   <none>        20001/TCP                                                                                                                 12m       app=kiali
service/prometheus               ClusterIP   10.109.4.73      <none>        9090/TCP                                                                                                                  12m       app=prometheus
service/servicegraph             ClusterIP   10.97.113.249    <none>        8088/TCP                                                                                                                  12m       app=servicegraph
service/tracing                  ClusterIP   10.96.21.32      <none>        80/TCP                                                                                                                    12m       app=jaeger
service/zipkin                   ClusterIP   10.111.24.171    <none>        9411/TCP                                                                                                                  12m       app=jaeger

NAME                                           DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS                 IMAGES                                                      SELECTOR
deployment.extensions/grafana                  1         1         1            1           12m       grafana                    grafana/grafana:5.2.3                                       app=grafana
deployment.extensions/istio-citadel            1         1         1            1           12m       citadel                    docker.io/istio/citadel:1.0.5                               istio=citadel
deployment.extensions/istio-egressgateway      1         1         1            1           12m       istio-proxy                docker.io/istio/proxyv2:1.0.5                               app=istio-egressgateway,istio=egressgateway
deployment.extensions/istio-galley             1         1         1            1           12m       validator                  docker.io/istio/galley:1.0.5                                istio=galley
deployment.extensions/istio-ingressgateway     1         1         1            1           12m       istio-proxy                docker.io/istio/proxyv2:1.0.5                               app=istio-ingressgateway,istio=ingressgateway
deployment.extensions/istio-pilot              1         1         1            1           12m       discovery,istio-proxy      docker.io/istio/pilot:1.0.5,docker.io/istio/proxyv2:1.0.5   app=pilot,istio=pilot
deployment.extensions/istio-policy             1         1         1            1           12m       mixer,istio-proxy          docker.io/istio/mixer:1.0.5,docker.io/istio/proxyv2:1.0.5   app=policy,istio=mixer,istio-mixer-type=policy
deployment.extensions/istio-sidecar-injector   1         1         1            1           12m       sidecar-injector-webhook   docker.io/istio/sidecar_injector:1.0.5                      istio=sidecar-injector
deployment.extensions/istio-telemetry          1         1         1            1           12m       mixer,istio-proxy          docker.io/istio/mixer:1.0.5,docker.io/istio/proxyv2:1.0.5   app=telemetry,istio=mixer,istio-mixer-type=telemetry
deployment.extensions/istio-tracing            1         1         1            1           12m       jaeger                     docker.io/jaegertracing/all-in-one:1.5                      app=jaeger
deployment.extensions/kiali                    1         1         1            1           12m       kiali                      docker.io/kiali/kiali:v0.10                                 app=kiali
deployment.extensions/prometheus               1         1         1            1           12m       prometheus                 docker.io/prom/prometheus:v2.3.1                            app=prometheus
deployment.extensions/servicegraph             1         1         1            1           12m       servicegraph               docker.io/istio/servicegraph:1.0.5                          app=servicegraph

NAME                                          READY     STATUS      RESTARTS   AGE       IP            NODE
pod/grafana-59b8896965-7hclc                  1/1       Running     0          12m       10.244.2.15   pruzicka-k8s-istio-demo-node03
pod/istio-citadel-856f994c58-tlkkb            1/1       Running     0          12m       10.244.1.19   pruzicka-k8s-istio-demo-node02
pod/istio-egressgateway-5649fcf57-gbwm9       1/1       Running     0          12m       10.244.2.16   pruzicka-k8s-istio-demo-node03
pod/istio-galley-7665f65c9c-mzw7p             1/1       Running     0          12m       10.244.1.22   pruzicka-k8s-istio-demo-node02
pod/istio-grafana-post-install-zdtgm          0/1       Completed   0          9m        10.244.1.24   pruzicka-k8s-istio-demo-node02
pod/istio-ingressgateway-6755b9bbf6-p6b5r     1/1       Running     0          12m       10.244.1.15   pruzicka-k8s-istio-demo-node02
pod/istio-pilot-56855d999b-sfwzz              2/2       Running     0          12m       10.244.2.18   pruzicka-k8s-istio-demo-node03
pod/istio-policy-6fcb6d655f-87lfs             2/2       Running     0          12m       10.244.1.17   pruzicka-k8s-istio-demo-node02
pod/istio-sidecar-injector-768c79f7bf-nnzjr   1/1       Running     0          12m       10.244.1.23   pruzicka-k8s-istio-demo-node02
pod/istio-telemetry-664d896cf5-54mps          2/2       Running     0          12m       10.244.1.16   pruzicka-k8s-istio-demo-node02
pod/istio-tracing-6b994895fd-fzmp6            1/1       Running     0          12m       10.244.1.21   pruzicka-k8s-istio-demo-node02
pod/kiali-67c69889b5-2fr28                    1/1       Running     0          12m       10.244.2.17   pruzicka-k8s-istio-demo-node03
pod/prometheus-76b7745b64-x8f85               1/1       Running     0          12m       10.244.1.18   pruzicka-k8s-istio-demo-node02
pod/servicegraph-5c4485945b-xdv56             1/1       Running     0          12m       10.244.1.20   pruzicka-k8s-istio-demo-node02
```

Configure Istio with a new log type and send those logs to the FluentD:

```bash
kubectl apply -f ../../yaml/fluentd-istio.yaml
```

## Istio example

Check how Istio can be used and how it works...

### Check + Enable Istio in default namespace

Let the default namespace to use Istio injection:

```bash
kubectl label namespace default istio-injection=enabled
```

Check namespaces:

```bash
kubectl get namespace -L istio-injection
```

Output:

```shell
NAME               STATUS    AGE       ISTIO-INJECTION
default            Active    40m       enabled
es-operator        Active    23m
istio-system       Active    12m
kube-public        Active    40m
kube-system        Active    40m
logging            Active    22m
rook-ceph          Active    34m
rook-ceph-system   Active    36m
```

Configure port forwarding for Istio services:

```bash
# Jaeger - http://localhost:16686
kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=jaeger -o jsonpath='{.items[0].metadata.name}') 16686:16686 &

# Prometheus UI - http://localhost:9090/graph
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}') 9090:9090 &

# Grafana - http://localhost:3000/dashboard/db/istio-mesh-dashboard
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &

# Kiali UI - http://localhost:20001
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=kiali -o jsonpath='{.items[0].metadata.name}') 20001:20001 &

# Servicegraph UI - http://localhost:8088/force/forcegraph.html
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}') 8088:8088 &
```

### Deploy application into the default namespace where Istio is enabled

The Bookinfo application is broken into four separate microservices:

* productpage - the productpage microservice calls the details and reviews microservices to populate the page.
* details - the details microservice contains book information.
* reviews - the reviews microservice contains book reviews. It also calls the ratings microservice.
* ratings - the ratings microservice contains book ranking information that accompanies a book review.

There are 3 versions of the `reviews` microservice:

* Version `v1` - doesn’t call the **ratings service**.
* Version `v2` - calls the ratings service, and displays each rating as 1 to 5 **black stars**.
* Version `v3` - calls the ratings service, and displays each rating as 1 to 5 **red stars**.

[Bookinfo](https://istio.io/docs/examples/bookinfo/) application architecture

![Application Architecture without Istio](https://istio.io/docs/examples/bookinfo/noistio.svg)

![Application Architecture with Istio](https://istio.io/docs/examples/bookinfo/withistio.svg)

Deploy the demo of [Bookinfo](https://istio.io/docs/examples/bookinfo/) application:

```bash
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
sleep 300
```

Confirm all services and pods are correctly defined and running:

```bash
kubectl get svc,deployment,pods -o wide
```

Output:

```shell
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
service/details       ClusterIP   10.97.156.143    <none>        9080/TCP   4m        app=details
service/kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP    58m       <none>
service/productpage   ClusterIP   10.111.118.194   <none>        9080/TCP   3m        app=productpage
service/ratings       ClusterIP   10.104.20.168    <none>        9080/TCP   3m        app=ratings
service/reviews       ClusterIP   10.97.181.246    <none>        9080/TCP   3m        app=reviews

NAME                                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS    IMAGES                                         SELECTOR
deployment.extensions/details-v1       1         1         1            1           3m        details       istio/examples-bookinfo-details-v1:1.8.0       app=details,version=v1
deployment.extensions/productpage-v1   1         1         1            1           3m        productpage   istio/examples-bookinfo-productpage-v1:1.8.0   app=productpage,version=v1
deployment.extensions/ratings-v1       1         1         1            1           3m        ratings       istio/examples-bookinfo-ratings-v1:1.8.0       app=ratings,version=v1
deployment.extensions/reviews-v1       1         1         1            1           3m        reviews       istio/examples-bookinfo-reviews-v1:1.8.0       app=reviews,version=v1
deployment.extensions/reviews-v2       1         1         1            1           3m        reviews       istio/examples-bookinfo-reviews-v2:1.8.0       app=reviews,version=v2
deployment.extensions/reviews-v3       1         1         1            1           3m        reviews       istio/examples-bookinfo-reviews-v3:1.8.0       app=reviews,version=v3

NAME                                      READY     STATUS    RESTARTS   AGE       IP            NODE
pod/details-v1-68c7c8666d-hwggx           2/2       Running   0          3m        10.244.2.40   pruzicka-k8s-istio-demo-node02
pod/elasticsearch-operator-sysctl-h5xds   1/1       Running   0          42m       10.244.2.10   pruzicka-k8s-istio-demo-node02
pod/elasticsearch-operator-sysctl-kx4pg   1/1       Running   0          42m       10.244.0.7    pruzicka-k8s-istio-demo-node01
pod/elasticsearch-operator-sysctl-pqbsz   1/1       Running   0          42m       10.244.1.9    pruzicka-k8s-istio-demo-node03
pod/productpage-v1-54d799c966-f75rv       2/2       Running   0          3m        10.244.1.22   pruzicka-k8s-istio-demo-node03
pod/ratings-v1-8558d4458d-l77gz           2/2       Running   0          3m        10.244.2.41   pruzicka-k8s-istio-demo-node02
pod/reviews-v1-cb8655c75-md9mg            2/2       Running   0          3m        10.244.1.21   pruzicka-k8s-istio-demo-node03
pod/reviews-v2-7fc9bb6dcf-qp4vs           2/2       Running   0          3m        10.244.0.12   pruzicka-k8s-istio-demo-node01
pod/reviews-v3-c995979bc-zf2kg            2/2       Running   0          3m        10.244.2.42   pruzicka-k8s-istio-demo-node02
```

Check the container details - you should see also container `istio-proxy` next to `productpage`:

```bash
kubectl describe pod -l app=productpage
kubectl logs $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') istio-proxy --tail=5
```

Define the ingress gateway for the application:

```bash
cat samples/bookinfo/networking/bookinfo-gateway.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
sleep 10
```

Confirm the gateway has been created:

```bash
kubectl get gateway,virtualservice
```

Output:

```shell
NAME                                           AGE
gateway.networking.istio.io/bookinfo-gateway   8s

NAME                                          AGE
virtualservice.networking.istio.io/bookinfo   7s
```

Determining the ingress IP and ports when using a node port:

```bash
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o 'jsonpath={.items[0].status.hostIP}')
# export INGRESS_HOST=$(terraform output -json -state=../../terraform.tfstate | jq -r '.vms_public_ip.value[0]')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo "$INGRESS_PORT | $SECURE_INGRESS_PORT | $INGRESS_HOST | $GATEWAY_URL"
```

Output:

```shell
31380 | 31390 | 172.16.241.103 | 172.16.241.103:31380
```

Confirm the app is running:

```bash
curl -o /dev/null -s -w "%{http_code}\n" -A "Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5" http://${GATEWAY_URL}/productpage
```

Output:

```shell
200
```

Create default destination rules (subsets) for the Bookinfo services:

```bash
kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

Display the destination rules:

```bash
kubectl get destinationrules -o yaml
```

Open the browser with these pages:

* [http://localhost:8088/force/forcegraph.html](http://localhost:8088/force/forcegraph.html)
* [http://localhost:8088/dotviz](http://localhost:8088/dotviz)
* [http://localhost:20001](http://localhost:20001) (Graph)
* [http://localhost:16686](http://localhost:16686)
* [http://localhost:3000](http://localhost:3000) (Grafana -> Home -> Istio -> Istio Performance Dashboard, Istio Service Dashboard, Istio Workload Dashboard )

Generate some traffic for next 5 minutes to gether some data:

```bash
siege --log=/tmp/siege --concurrent=1 -q --internet --time=5M $GATEWAY_URL/productpage &
```

![Istio Graph](images/istio_kiali_graph.gif "Istio Graph")

### Configuring Request Routing

[https://istio.io/docs/tasks/traffic-management/request-routing/](https://istio.io/docs/tasks/traffic-management/request-routing/)

Apply the virtual services which will route all traffic to **v1** of each microservice:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

Display the defined routes:

```bash
kubectl get virtualservices -o yaml
```

Output:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: details
  ...
spec:
  hosts:
  - details
  http:
  - route:
    - destination:
        host: details
        subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productpage
  ...
spec:
  gateways:
  - bookinfo-gateway
  - mesh
  hosts:
  - productpage
  http:
  - route:
    - destination:
        host: productpage
        subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
  ...
spec:
  hosts:
  - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
  ...
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
```

* Open the Bookinfo site in your browser `http://$GATEWAY_URL/productpage` and notice that the reviews part of the page displays with no rating stars, no matter how many times you refresh.

![Bookinfo v1](images/bookinfo_v1.jpg "Bookinfo v1")

### Route based on user identity

[https://istio.io/docs/tasks/traffic-management/request-routing/#route-based-on-user-identity](https://istio.io/docs/tasks/traffic-management/request-routing/#route-based-on-user-identity)

All traffic from a user named `jason` will be routed to the service `reviews:v2` by forwarding HTTP requests with custom end-user header to the appropriate reviews service.

Enable user-based routing:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml
```

Confirm the rule is created:

```bash
kubectl get virtualservice reviews -o yaml
```

Output:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
  ...
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

* On the /productpage of the Bookinfo app, log in as user `jason` and refresh the browser.

* Log in as another user (pick any name you wish) and refresh the browser

![Bookinfo v2](images/bookinfo_v2.jpg "Bookinfo v2")

You can do the same with user-agent header for example:

```yaml
  http:
    - match:
        - headers:
            user-agent:
              regex: '.*Firefox.*'
```

### Injecting an HTTP delay fault

[https://istio.io/docs/tasks/traffic-management/fault-injection/#injecting-an-http-delay-fault](https://istio.io/docs/tasks/traffic-management/fault-injection/#injecting-an-http-delay-fault)

Inject a 7s delay between the `reviews:v2` and ratings microservices for user `jason`:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-ratings-test-delay.yaml
```

Confirm the rule was created:

```bash
kubectl get virtualservice ratings -o yaml
```

Output:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
  ...
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        fixedDelay: 7s
        percent: 100
    match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

* On the `/productpage`, log in as user `jason` adn you should see:

```text
Error fetching product reviews!
Sorry, product reviews are currently unavailable for this book.
```

* Open the Developer Tools menu (F12) -> Network tab - webpage actually loads in about 6 seconds.

* Open Jaeger UI [http://localhost:16686](http://localhost:16686) and check the length of the query

### Injecting an HTTP abort fault

[https://istio.io/docs/tasks/traffic-management/fault-injection/#injecting-an-http-abort-fault](https://istio.io/docs/tasks/traffic-management/fault-injection/#injecting-an-http-abort-fault)

Let's ntroduce an HTTP abort to the ratings microservices for the test user `jason`.

Create a fault injection rule to send an HTTP abort for user `jason`:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-ratings-test-abort.yaml
```

Confirm the rule was created:

```bash
kubectl get virtualservice ratings -o yaml
```

Output:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
  ...
spec:
  hosts:
  - ratings
  http:
  - fault:
      abort:
        httpStatus: 500
        percent: 100
    match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

* On the `/productpage`, log in as user `jason` - the page loads immediately and the product ratings not available message appears.

![Injecting an HTTP abort fault Kiali Graph](images/istio_kiali_injecting_an_http_abort_fault.gif "Injecting an HTTP abort fault Kiali Graph")

* Remove the application routing rules:

```bash
kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

### Weight-based routing

[https://istio.io/docs/tasks/traffic-management/traffic-shifting/#apply-weight-based-routing](https://istio.io/docs/tasks/traffic-management/traffic-shifting/#apply-weight-based-routing)

In **Canary Deployments**, newer versions of services are incrementally rolled out to users to minimize the risk and impact of any bugs introduced by the newer version.

Route a percentage of traffic to one service or another - send **%50** of traffic to `reviews:v1` and **%50** to `reviews:v3` and finally complete the migration by sending %100 of traffic to `reviews:v3`.

Route all traffic to the `reviews:v1` version of each microservice:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

Transfer 50% of the traffic from `reviews:v1` to `reviews:v3`:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-50-v3.yaml
```

Confirm the rule was replaced:

```bash
kubectl get virtualservice reviews -o yaml
```

Output:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
  ...
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 50
    - destination:
        host: reviews
        subset: v3
      weight: 50
```

* Refresh the `/productpage` in your browser and you now see **red** colored star ratings approximately **50%** of the time.

![Weight-based routing Kiali Graph](images/istio_kiali_weight-based_routing.gif "Weight-based routing Kiali Graph")

Assuming you decide that the `reviews:v3` microservice is stable, you can route **100%** of the traffic to `reviews:v3` by applying this virtual service.

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-reviews-v3.yaml
```

* When you refresh the `/productpage` you will always see book reviews with **red** colored star ratings for **each** review.

![Bookinfo v3](images/bookinfo_v3.jpg "Bookinfo v3")

* Remove the application routing rules:

```bash
kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

### Mirroring

[https://istio.io/docs/tasks/traffic-management/mirroring/](https://istio.io/docs/tasks/traffic-management/mirroring/)

Mirroring sends a copy of live traffic to a mirrored service.

First all traffic will go to `reviews:v1`, then the rule will be applied to mirror a portion of traffic to `reviews:v2`.

Apply the virtual services which will route all traffic to `v1` of each microservice:

```bash
kubectl apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

Change the route rule to mirror traffic to `v2`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
    mirror:
      host: reviews
      subset: v2
EOF
```

Check the logs on both pods `reviews:v1` and `reviews:v2`:

```bash
kubectl logs $(kubectl get pod -l app=reviews,version=v1 -o jsonpath='{.items[0].metadata.name}') istio-proxy --tail=10
kubectl logs $(kubectl get pod -l app=reviews,version=v2 -o jsonpath='{.items[0].metadata.name}') istio-proxy --tail=10
```

Do a simple query:

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
```

![Mirroring Kiali Graph](images/istio_kiali_mirroring.gif "Mirroring Kiali Graph")

* Remove the application routing rules:

```bash
kubectl delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml
```

## List of GUIs

* Jaeger - [https://istio.io/docs/tasks/telemetry/distributed-tracing/](https://istio.io/docs/tasks/telemetry/distributed-tracing/)

    ```shell
    kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=jaeger -o jsonpath='{.items[0].metadata.name}') 16686:16686 &
    ```

    Link: [http://localhost:16686](http://localhost:16686)

* Prometheus UI - [https://istio.io/docs/tasks/telemetry/querying-metrics/](https://istio.io/docs/tasks/telemetry/querying-metrics/)

    ```shell
    kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}') 9090:9090 &
    ```

    Link: [http://localhost:9090/graph](http://localhost:9090/graph)

* Grafana - [https://istio.io/docs/tasks/telemetry/using-istio-dashboard/](https://istio.io/docs/tasks/telemetry/using-istio-dashboard/)

    ```shell
    kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &
    ```

    Link: [http://localhost:3000/dashboard/db/istio-mesh-dashboard](http://localhost:3000/dashboard/db/istio-mesh-dashboard)

* Kiali UI - [https://istio.io/docs/tasks/telemetry/kiali/](https://istio.io/docs/tasks/telemetry/kiali/)

    ```shell
    kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=kiali -o jsonpath='{.items[0].metadata.name}') 20001:20001 &
    ```

    Login: admin

    Password: admin

    Link: [http://localhost:20001](http://localhost:20001)

* Servicegraph UI - [https://istio.io/docs/tasks/telemetry/servicegraph/](https://istio.io/docs/tasks/telemetry/servicegraph/)

    ```shell
    kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}') 8088:8088 &
    ```

    Link: [http://localhost:8088/force/forcegraph.html](http://localhost:8088/force/forcegraph.html), [http://localhost:8088/dotviz](http://localhost:8088/dotviz)

* Kibana UI

    ```shell
    kubectl -n logging port-forward $(kubectl -n logging get pod -l role=kibana -o jsonpath='{.items[0].metadata.name}') 5601:5601 &
    ```

    Link: [https://localhost:5601](https://localhost:5601)

* Cerbero

    ```shell
    kubectl -n logging port-forward $(kubectl -n logging get pod -l role=cerebro -o jsonpath='{.items[0].metadata.name}') 9000:9000 &
    ```

    Link: [http://localhost:9000](http://localhost:9000)

* Ceph Dashboard

    ```shell
    kubectl -n rook-ceph port-forward $(kubectl -n rook-ceph get pod -l app=rook-ceph-mgr -o jsonpath='{.items[0].metadata.name}') 8443:8443 &
    ```

    Login: admin

    Password: `kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o yaml | grep "password:" | awk '{print $2}' | base64 --decode`

    Link: [https://localhost:8443/ceph-dashboard](https://localhost:8443/ceph-dashboard)

## Links

* [Istio Service Mesh by Mete Atamel @ .NET Conf UY v2018](https://www.youtube.com/watch?v=sh0F7FMFVSI)

* [Liam White - Istio @ GDGReading DevFest 2018](https://www.youtube.com/watch?v=RVScqW8_liw)

* [Istio Service Mesh & pragmatic microservices architecture - Álex Soto](https://www.youtube.com/watch?v=OAW5rbttic0)

* [Introduction - Istio 101 Lab](https://istio101.gitbook.io/lab/workshop/)

* [Using Istio Workshop by Layer5.io](https://github.com/leecalcote/istio-service-mesh-workshop)

* [Istio Workshop by Ray Tsang](https://github.com/retroryan/istio-workshop)

* [Amazon EKS Workshop - Service Mesh with Istio](https://eksworkshop.com/servicemesh/)
