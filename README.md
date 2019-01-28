# Kubernetes with Istio running on top of OpenStack demo

Find below few commands showing basics of Istio...

## Requirements

* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (kubernetes-client package)
* [Helm](https://helm.sh/)
* [Terraform](https://www.terraform.io/)

## Provision VMs in OpenStack

Start 3 VMs (one master and 2 workers) where the k8s will be installed.

Generate ssh keys if not exists.

```bash
test -f $HOME/.ssh/id_rsa || ( install -m 0700 -d $HOME/.ssh && ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -q -N "" )
```

Clone this repo.

```bash
git clone https://github.com/ruzickap/k8s-istio-demo
cd k8s-istio-demo
```

Modify the terraform variable file if needed.

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
EOF
```

Download terraform components.

```bash
terraform init -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
```

Create VMs in OpenStack.

```bash
terraform apply -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
```

Show terraform output.

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
    172.16.241.250,
    172.16.241.48,
    172.16.244.142
]
```

At the end of the output you should see 3 IP addresses which should be accessible by ssh using your public key (~/.ssh/id_rsa.pub)

## Install k8s

Install k8s using kubeadm to the provisioned VMs.

```bash
./install-k8s-kubeadm.sh
```

Check if all nodes are up

```bash
export KUBECONFIG=$PWD/kubeconfig.conf
kubectl get nodes -o wide
```

Output:

```shell
NAME                             STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
pruzicka-k8s-istio-demo-node01   Ready     master    6m        v1.13.2   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://18.6.1
pruzicka-k8s-istio-demo-node02   Ready     <none>    5m        v1.13.2   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://18.6.1
pruzicka-k8s-istio-demo-node03   Ready     <none>    5m        v1.13.2   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://18.6.1
```

View services, deployments, and pods.

``` bash
kubectl get svc,deploy,po --all-namespaces -o wide
```

Output:

```shell
NAMESPACE     NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE       SELECTOR
default       service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP         2m        <none>
kube-system   service/kube-dns     ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   2m        k8s-app=kube-dns

NAMESPACE     NAME                            DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS   IMAGES                     SELECTOR
kube-system   deployment.extensions/coredns   2         2         2            0           2m        coredns      k8s.gcr.io/coredns:1.2.6   k8s-app=kube-dns

NAMESPACE     NAME                                                         READY     STATUS              RESTARTS   AGE       IP               NODE
kube-system   pod/coredns-86c58d9df4-bxdtq                                 0/1       ContainerCreating   0          1m        <none>           pruzicka-k8s-istio-demo-node02
kube-system   pod/coredns-86c58d9df4-rp7tq                                 0/1       ContainerCreating   0          1m        <none>           pruzicka-k8s-istio-demo-node02
kube-system   pod/etcd-pruzicka-k8s-istio-demo-node01                      1/1       Running             0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-apiserver-pruzicka-k8s-istio-demo-node01            1/1       Running             0          51s       192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-controller-manager-pruzicka-k8s-istio-demo-node01   1/1       Running             0          45s       192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-flannel-ds-amd64-6vkt6                              1/1       Running             0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-flannel-ds-amd64-fjtqb                              1/1       Running             0          42s       192.168.250.13   pruzicka-k8s-istio-demo-node03
kube-system   pod/kube-flannel-ds-amd64-qq8g6                              0/1       Init:0/1            0          45s       192.168.250.12   pruzicka-k8s-istio-demo-node02
kube-system   pod/kube-proxy-4ltgf                                         1/1       Running             0          42s       192.168.250.13   pruzicka-k8s-istio-demo-node03
kube-system   pod/kube-proxy-cbxvg                                         1/1       Running             0          45s       192.168.250.12   pruzicka-k8s-istio-demo-node02
kube-system   pod/kube-proxy-gbf2f                                         1/1       Running             0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
kube-system   pod/kube-scheduler-pruzicka-k8s-istio-demo-node01            1/1       Running             0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
```

## Install Helm

Install Tiller (the Helm server-side component) into the Kubernetes Cluster.

```bash
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --wait --service-account tiller
helm repo update
```

Check if the tiller was installed properly

```bash
kubectl get pods -l app=helm  --all-namespaces
```

Output:

```shell
NAMESPACE     NAME                            READY     STATUS    RESTARTS   AGE
kube-system   tiller-deploy-dbb85cb99-v9krv   1/1       Running   0          8m
```

## Instal Rook

Install Rook (Ceph storage for k8s)

```bash
helm repo add rook-stable https://charts.rook.io/stable
helm install --wait --name rook-ceph --namespace rook-ceph-system rook-stable/rook-ceph
```

See how the rook-ceph-system should look like:

```bash
kubectl get svc,deploy,po --namespace=rook-ceph-system -o wide
```

Output:

```shell
NAME                                       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS           IMAGES             SELECTOR
deployment.extensions/rook-ceph-operator   1         1         1            1           2m        rook-ceph-operator   rook/ceph:v0.9.1   app=rook-ceph-operator

NAME                                     READY     STATUS    RESTARTS   AGE       IP               NODE
pod/rook-ceph-agent-l8f6x                1/1       Running   0          1m        192.168.250.13   pruzicka-k8s-istio-demo-node03
pod/rook-ceph-agent-mrs9l                1/1       Running   0          1m        192.168.250.12   pruzicka-k8s-istio-demo-node02
pod/rook-ceph-agent-p9zs6                1/1       Running   0          1m        192.168.250.11   pruzicka-k8s-istio-demo-node01
pod/rook-ceph-operator-86554fd8d-62v7s   1/1       Running   0          2m        10.244.2.2       pruzicka-k8s-istio-demo-node03
pod/rook-discover-529q5                  1/1       Running   0          1m        10.244.1.5       pruzicka-k8s-istio-demo-node02
pod/rook-discover-km7z9                  1/1       Running   0          1m        10.244.0.2       pruzicka-k8s-istio-demo-node01
pod/rook-discover-zf7lr                  1/1       Running   0          1m        10.244.2.3       pruzicka-k8s-istio-demo-node03
```

Create your Rook cluster

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml
sleep 120
```

Check what was created in `rook-ceph` namespace

```bash
kubectl get svc,deploy,po --namespace=rook-ceph -o wide
```

Output:

```shell
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
service/rook-ceph-mgr             ClusterIP   10.107.54.155    <none>        9283/TCP   1m        app=rook-ceph-mgr,rook_cluster=rook-ceph
service/rook-ceph-mgr-dashboard   ClusterIP   10.107.31.93     <none>        8443/TCP   1m        app=rook-ceph-mgr,rook_cluster=rook-ceph
service/rook-ceph-mon-a           ClusterIP   10.105.35.157    <none>        6790/TCP   3m        app=rook-ceph-mon,ceph_daemon_id=a,mon=a,mon_cluster=rook-ceph,rook_cluster=rook-ceph
service/rook-ceph-mon-b           ClusterIP   10.110.219.74    <none>        6790/TCP   2m        app=rook-ceph-mon,ceph_daemon_id=b,mon=b,mon_cluster=rook-ceph,rook_cluster=rook-ceph
service/rook-ceph-mon-c           ClusterIP   10.101.102.201   <none>        6790/TCP   2m        app=rook-ceph-mon,ceph_daemon_id=c,mon=c,mon_cluster=rook-ceph,rook_cluster=rook-ceph

NAME                                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS   IMAGES          SELECTOR
deployment.extensions/rook-ceph-mgr-a   1         1         1            1           1m        mgr          ceph/ceph:v13   app=rook-ceph-mgr,ceph_daemon_id=a,instance=a,mgr=a,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-mon-a   1         1         1            1           3m        mon          ceph/ceph:v13   app=rook-ceph-mon,ceph_daemon_id=a,mon=a,mon_cluster=rook-ceph,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-mon-b   1         1         1            1           2m        mon          ceph/ceph:v13   app=rook-ceph-mon,ceph_daemon_id=b,mon=b,mon_cluster=rook-ceph,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-mon-c   1         1         1            1           2m        mon          ceph/ceph:v13   app=rook-ceph-mon,ceph_daemon_id=c,mon=c,mon_cluster=rook-ceph,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-osd-0   1         1         1            1           1m        osd          ceph/ceph:v13   app=rook-ceph-osd,ceph-osd-id=0,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-osd-1   1         1         1            1           59s       osd          ceph/ceph:v13   app=rook-ceph-osd,ceph-osd-id=1,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-osd-2   1         1         1            1           59s       osd          ceph/ceph:v13   app=rook-ceph-osd,ceph-osd-id=2,rook_cluster=rook-ceph

NAME                                                             READY     STATUS      RESTARTS   AGE       IP            NODE
pod/rook-ceph-mgr-a-5ffc8f5b48-t6gqb                             1/1       Running     0          1m        10.244.2.5    pruzicka-k8s-istio-demo-node03
pod/rook-ceph-mon-a-7448c9678d-24xvl                             1/1       Running     0          3m        10.244.0.3    pruzicka-k8s-istio-demo-node01
pod/rook-ceph-mon-b-7fb9596458-n8mdk                             1/1       Running     0          2m        10.244.1.8    pruzicka-k8s-istio-demo-node02
pod/rook-ceph-mon-c-748567cfc8-9wkns                             1/1       Running     0          2m        10.244.2.4    pruzicka-k8s-istio-demo-node03
pod/rook-ceph-osd-0-7695749cb5-kjtv7                             1/1       Running     0          1m        10.244.0.5    pruzicka-k8s-istio-demo-node01
pod/rook-ceph-osd-1-6b9b575587-dxxph                             1/1       Running     0          59s       10.244.2.7    pruzicka-k8s-istio-demo-node03
pod/rook-ceph-osd-2-84b9bfbb56-9gc45                             1/1       Running     0          59s       10.244.1.10   pruzicka-k8s-istio-demo-node02
pod/rook-ceph-osd-prepare-pruzicka-k8s-istio-demo-node01-kr9g2   0/2       Completed   0          1m        10.244.0.4    pruzicka-k8s-istio-demo-node01
pod/rook-ceph-osd-prepare-pruzicka-k8s-istio-demo-node02-g46tm   0/2       Completed   0          1m        10.244.1.9    pruzicka-k8s-istio-demo-node02
pod/rook-ceph-osd-prepare-pruzicka-k8s-istio-demo-node03-vdtt8   0/2       Completed   0          1m        10.244.2.6    pruzicka-k8s-istio-demo-node03
```

Get the Toolbox with ceph commands

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/toolbox.yaml
```

The deployment with `rook-ceph-tools` was created

```bash
kubectl get deploy,po --namespace=rook-ceph -o wide -l app=rook-ceph-tools
```

Output:

```shell
NAME                                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS        IMAGES             SELECTOR
deployment.extensions/rook-ceph-tools   1         1         1            1           1m        rook-ceph-tools   rook/ceph:master   app=rook-ceph-tools

NAME                                   READY     STATUS    RESTARTS   AGE       IP               NODE
pod/rook-ceph-tools-76c7d559b6-pxdwk   1/1       Running   0          1m        192.168.250.13   pruzicka-k8s-istio-demo-node03
```

Create a storage class based on the Ceph RBD volume plugin

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/storageclass.yaml
```

Set `rook-ceph-block`

```bash
kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Check the storageclasses

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

See the CephBlockPool

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
  Creation Timestamp:  2019-01-26T10:45:44Z
  Generation:          1
  Resource Version:    10142
  Self Link:           /apis/ceph.rook.io/v1/namespaces/rook-ceph/cephblockpools/replicapool
  UID:                 88577f55-2157-11e9-a723-fa163e3d2a7d
Spec:
  Replicated:
    Size:  1
Events:    <none>
```

Check the status of your Ceph installation

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph status
```

Output:

```shell
  cluster:
    id:     690d318f-fc9f-4743-b14b-27e710009c8a
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum b,a,c
    mgr: a(active)
    osd: 3 osds: 3 up, 3 in

  data:
    pools:   1 pools, 100 pgs
    objects: 0  objects, 0 B
    usage:   13 GiB used, 44 GiB / 58 GiB avail
    pgs:     100 active+clean
```

Ceph status

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd status
```

Output:

```shell
+----+--------------------------------+-------+-------+--------+---------+--------+---------+-----------+
| id |              host              |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+--------------------------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | pruzicka-k8s-istio-demo-node02 | 4376M | 14.9G |    0   |     0   |    0   |     0   | exists,up |
| 1  | pruzicka-k8s-istio-demo-node01 | 4936M | 14.3G |    0   |     0   |    0   |     0   | exists,up |
| 2  | pruzicka-k8s-istio-demo-node03 | 4354M | 14.9G |    0   |     0   |    0   |     0   | exists,up |
+----+--------------------------------+-------+-------+--------+---------+--------+---------+-----------+
```

Check health detail of Ceph cluster

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph health detail
```

Output:

```shell
HEALTH_OK
```

Check monitor quorum status of Ceph

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph quorum_status --format json-pretty
```

Dump monitoring information from Ceph

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph mon dump
```

Output:

```shell
epoch 3
fsid 690d318f-fc9f-4743-b14b-27e710009c8a
last_changed 2019-01-26 09:51:14.531755
created 2019-01-26 09:50:11.739704
0: 10.100.171.206:6790/0 mon.b
1: 10.108.79.108:6790/0 mon.a
2: 10.111.159.21:6790/0 mon.c
dumped monmap epoch 3
```

Check the cluster usage status

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph df
```

Output:

```shell
GLOBAL:
    SIZE       AVAIL      RAW USED     %RAW USED
    58 GiB     44 GiB       13 GiB         23.16
POOLS:
    NAME            ID     USED     %USED     MAX AVAIL     OBJECTS
    replicapool     1       0 B         0        40 GiB           0
```

Check OSD usage of Ceph

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd df
```

Output:

```shell
ID CLASS WEIGHT  REWEIGHT SIZE   USE     AVAIL  %USE  VAR  PGS
 1   hdd 0.01880  1.00000 19 GiB 4.8 GiB 14 GiB 25.10 1.08  32
 0   hdd 0.01880  1.00000 19 GiB 4.3 GiB 15 GiB 22.25 0.96  36
 2   hdd 0.01880  1.00000 19 GiB 4.3 GiB 15 GiB 22.14 0.96  32
                    TOTAL 58 GiB  13 GiB 44 GiB 23.16
MIN/MAX VAR: 0.96/1.08  STDDEV: 1.37
```

Check the Ceph monitor

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph mon stat
```

Output:

```shell
e3: 3 mons at {a=10.108.79.108:6790/0,b=10.100.171.206:6790/0,c=10.111.159.21:6790/0}, election epoch 14, leader 0 b, quorum 0,1,2 b,a,c
```

Check OSD stats

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd stat
```

Output:

```shell
3 osds: 3 up, 3 in; epoch: e17
```

Check pool stats

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd pool stats
```

Output:

```shell
pool replicapool id 1
  nothing is going on
```

Check pg stats

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph pg stat
```

Output:

```shell
100 pgs: 100 active+clean; 0 B data, 13 GiB used, 44 GiB / 58 GiB avail
```

List the Ceph pools in detail

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd pool ls detail
```

Output:

```shell
pool 1 'replicapool' replicated size 1 min_size 1 crush_rule 1 object_hash rjenkins pg_num 100 pgp_num 100 last_change 17 flags hashpspool stripe_width 0 application rbd
```

Check the CRUSH map view of OSDs

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd tree
```

Output:

```shell
ID CLASS WEIGHT  TYPE NAME                               STATUS REWEIGHT PRI-AFF
-1       0.05640 root default
-2       0.01880     host pruzicka-k8s-istio-demo-node01
 1   hdd 0.01880         osd.1                               up  1.00000 1.00000
-4       0.01880     host pruzicka-k8s-istio-demo-node02
 0   hdd 0.01880         osd.0                               up  1.00000 1.00000
-3       0.01880     host pruzicka-k8s-istio-demo-node03
 2   hdd 0.01880         osd.2                               up  1.00000 1.00000
```

List the cluster authentication keys

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph auth list
```

## Install ElasticSearch, Kibana, Fluentbit

Install Elasticsearch

```bash
helm install --wait stable/elasticsearch --name=elasticsearch --namespace=logging
```

Show ElasticSearch components

```bash
kubectl get svc,deploy,po,pvc --namespace=logging -o wide
```

Output:

```shell
NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE       SELECTOR
service/elasticsearch-client      ClusterIP   10.96.102.55   <none>        9200/TCP   7m        app=elasticsearch,component=client,release=elasticsearch
service/elasticsearch-discovery   ClusterIP   None           <none>        9300/TCP   7m        app=elasticsearch,component=master,release=elasticsearch

NAME                                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS      IMAGES                                                    SELECTOR
deployment.extensions/elasticsearch-client   2         2         2            2           7m        elasticsearch   docker.elastic.co/elasticsearch/elasticsearch-oss:6.5.4   app=elasticsearch,component=client,release=elasticsearch

NAME                                        READY     STATUS    RESTARTS   AGE       IP            NODE
pod/elasticsearch-client-745c4d764c-4mz84   1/1       Running   0          7m        10.244.2.10   pruzicka-k8s-istio-demo-node03
pod/elasticsearch-client-745c4d764c-zqcl5   1/1       Running   0          7m        10.244.0.10   pruzicka-k8s-istio-demo-node01
pod/elasticsearch-data-0                    1/1       Running   0          7m        10.244.2.11   pruzicka-k8s-istio-demo-node03
pod/elasticsearch-data-1                    1/1       Running   0          5m        10.244.0.12   pruzicka-k8s-istio-demo-node01
pod/elasticsearch-master-0                  1/1       Running   0          7m        10.244.0.11   pruzicka-k8s-istio-demo-node01
pod/elasticsearch-master-1                  1/1       Running   0          6m        10.244.2.12   pruzicka-k8s-istio-demo-node03
pod/elasticsearch-master-2                  1/1       Running   0          6m        10.244.1.7    pruzicka-k8s-istio-demo-node02

NAME                                                STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
persistentvolumeclaim/data-elasticsearch-data-0     Bound     pvc-7b63cc03-20dd-11e9-b19e-fa163e6e8da4   30Gi       RWO            rook-ceph-block   7m
persistentvolumeclaim/data-elasticsearch-data-1     Bound     pvc-d1424d70-20dd-11e9-b19e-fa163e6e8da4   30Gi       RWO            rook-ceph-block   5m
persistentvolumeclaim/data-elasticsearch-master-0   Bound     pvc-7b67c675-20dd-11e9-b19e-fa163e6e8da4   4Gi        RWO            rook-ceph-block   7m
persistentvolumeclaim/data-elasticsearch-master-1   Bound     pvc-9e261bd1-20dd-11e9-b19e-fa163e6e8da4   4Gi        RWO            rook-ceph-block   6m
persistentvolumeclaim/data-elasticsearch-master-2   Bound     pvc-b023b491-20dd-11e9-b19e-fa163e6e8da4   4Gi        RWO            rook-ceph-block   6m
```

Install Fluentbit

```bash
helm install --wait stable/fluent-bit --name=fluent-bit --namespace=logging --set backend.type=es --set backend.es.host=elasticsearch-client
```

Install Kibana

```bash
helm install --wait stable/kibana --name=kibana --namespace=logging --set env.ELASTICSEARCH_URL=http://elasticsearch-client:9200
```

## Install Istio

Either download Istio directly from [https://github.com/istio/istio/releases](https://github.com/istio/istio/releases) or get the latest version by using curl:

```bash
cd files
curl -L https://git.io/getLatestIstio | sh -
```

Change the directory to the Istio installation files location.

```bash
cd istio*
```

Install Istio using helm

```bash
helm install --wait install/kubernetes/helm/istio --name istio --namespace istio-system \
  --set gateways.istio-ingressgateway.type=NodePort \
  --set gateways.istio-egressgateway.type=NodePort \
  --set grafana.enabled=true \
  --set kiali.enabled=true \
  --set servicegraph.enabled=true \
  --set telemetry-gateway.grafanaEnabled=true \
  --set telemetry-gateway.prometheusEnabled=true \
  --set tracing.enabled=true
```

Configure Istio with a new log type and send those logs to the FluentD

```bash
kubectl apply -f ../../yaml/fluentd-istio.yaml
```

## Istio example

Let the default namespace to use istio injection

```bash
kubectl label namespace default istio-injection=enabled
```

Check namespaces

```bash
kubectl get namespace -L istio-injection
```

Output:

```shell
NAME               STATUS    AGE       ISTIO-INJECTION
default            Active    2h        enabled
istio-system       Active    26m
kube-public        Active    2h
kube-system        Active    2h
logging            Active    48m
rook-ceph          Active    1h
rook-ceph-system   Active    1h
```

Deploy the demo application [https://istio.io/docs/examples/bookinfo/](https://istio.io/docs/examples/bookinfo/)

```bash
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

Define the ingress gateway for the application

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

Check the deployed application

```bash
kubectl get svc,deployment,pods,gateway,virtualservice -o wide
```

Output:

```shell
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
service/details       ClusterIP   10.109.115.104   <none>        9080/TCP   14m       app=details
service/kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP    3h        <none>
service/productpage   ClusterIP   10.103.215.143   <none>        9080/TCP   14m       app=productpage
service/ratings       ClusterIP   10.107.250.205   <none>        9080/TCP   14m       app=ratings
service/reviews       ClusterIP   10.110.97.233    <none>        9080/TCP   14m       app=reviews

NAME                                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS    IMAGES                                         SELECTOR
deployment.extensions/details-v1       1         1         1            1           14m       details       istio/examples-bookinfo-details-v1:1.8.0       app=details,version=v1
deployment.extensions/productpage-v1   1         1         1            1           14m       productpage   istio/examples-bookinfo-productpage-v1:1.8.0   app=productpage,version=v1
deployment.extensions/ratings-v1       1         1         1            1           14m       ratings       istio/examples-bookinfo-ratings-v1:1.8.0       app=ratings,version=v1
deployment.extensions/reviews-v1       1         1         1            1           14m       reviews       istio/examples-bookinfo-reviews-v1:1.8.0       app=reviews,version=v1
deployment.extensions/reviews-v2       1         1         1            1           14m       reviews       istio/examples-bookinfo-reviews-v2:1.8.0       app=reviews,version=v2
deployment.extensions/reviews-v3       1         1         1            1           14m       reviews       istio/examples-bookinfo-reviews-v3:1.8.0       app=reviews,version=v3

NAME                                  READY     STATUS    RESTARTS   AGE       IP            NODE
pod/details-v1-68c7c8666d-gzl4q       2/2       Running   0          14m       10.244.2.18   pruzicka-k8s-istio-demo-node03
pod/productpage-v1-54d799c966-ccxvx   2/2       Running   0          14m       10.244.0.16   pruzicka-k8s-istio-demo-node01
pod/ratings-v1-8558d4458d-brr9n       2/2       Running   0          14m       10.244.2.19   pruzicka-k8s-istio-demo-node03
pod/reviews-v1-cb8655c75-dldsp        2/2       Running   0          14m       10.244.0.15   pruzicka-k8s-istio-demo-node01
pod/reviews-v2-7fc9bb6dcf-qkfdg       2/2       Running   0          14m       10.244.2.20   pruzicka-k8s-istio-demo-node03
pod/reviews-v3-c995979bc-vpqxq        2/2       Running   0          14m       10.244.1.20   pruzicka-k8s-istio-demo-node02

NAME                                           AGE
gateway.networking.istio.io/bookinfo-gateway   14m

NAME                                          AGE
virtualservice.networking.istio.io/bookinfo   14m
```

Determining the ingress IP and ports when using a node port

```bash
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
# export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o 'jsonpath={.items[0].status.hostIP}')
export INGRESS_HOST=$(terraform output -json -state=../../terraform.tfstate | jq -r '.vms_public_ip.value[0]')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo "$INGRESS_PORT | $SECURE_INGRESS_PORT | $INGRESS_HOST | $GATEWAY_URL"
```

Output:

```shell
31380 | 31390 | 172.16.241.11 | 172.16.241.11:31380
```

Confirm the app is running

```bash
curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
```

Output:

```shell
200
```

## List of GUIs

* Jaeger [https://istio.io/docs/tasks/telemetry/distributed-tracing/](https://istio.io/docs/tasks/telemetry/distributed-tracing/)

```bash
kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=jaeger -o jsonpath='{.items[0].metadata.name}') 16686:16686 &
```

Link: [http://localhost:16686](http://localhost:16686)

* Prometheus UI [https://istio.io/docs/tasks/telemetry/querying-metrics/](https://istio.io/docs/tasks/telemetry/querying-metrics/)

```bash
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}') 9090:9090 &
```

Link: [http://localhost:9090/graph](http://localhost:9090/graph)

* Grafana [https://istio.io/docs/tasks/telemetry/using-istio-dashboard/](https://istio.io/docs/tasks/telemetry/using-istio-dashboard/)

```bash
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &
```

Link: [http://localhost:3000/dashboard/db/istio-mesh-dashboard](http://localhost:3000/dashboard/db/istio-mesh-dashboard)

* Kiali UI [https://istio.io/docs/tasks/telemetry/kiali/](https://istio.io/docs/tasks/telemetry/kiali/)

```bash
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=kiali -o jsonpath='{.items[0].metadata.name}') 20001:20001 &
```

Link: [http://localhost:20001](http://localhost:20001) (admin/admin)

* Servicegraph UI [https://istio.io/docs/tasks/telemetry/servicegraph/](https://istio.io/docs/tasks/telemetry/servicegraph/)

```bash
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}') 8088:8088 &
```

Link: [http://localhost:8088/force/forcegraph.html](http://localhost:8088/force/forcegraph.html)

* Kibana UI

```bash
kubectl -n logging port-forward $(kubectl -n logging get pod -l app=kibana -o jsonpath='{.items[0].metadata.name}') 5601:5601 &
```

Link: [http://localhost:5601](http://localhost:5601)

* Ceph Dashboard

```bash
kubectl -n rook-ceph port-forward $(kubectl -n rook-ceph get pod -l app=rook-ceph-mgr -o jsonpath='{.items[0].metadata.name}') 8443:8443 &
```

Login: admin
Password: kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o yaml | grep "password:" | awk '{print $2}' | base64 --decode
Link: [https://localhost:8443/ceph-dashboard](https://localhost:8443/ceph-dashboard)

## Handy links

* [https://www.youtube.com/watch?v=sh0F7FMFVSI](https://www.youtube.com/watch?v=sh0F7FMFVSI)

* [https://www.youtube.com/watch?v=yxmBpHjCB3k](https://www.youtube.com/watch?v=yxmBpHjCB3k)

* [https://www.youtube.com/watch?v=RVScqW8_liw](https://www.youtube.com/watch?v=RVScqW8_liw)

* [https://www.youtube.com/watch?v=OAW5rbttic0](https://www.youtube.com/watch?v=OAW5rbttic0)

* [https://istio101.gitbook.io/lab/workshop/](https://istio101.gitbook.io/lab/workshop/)

* [https://github.com/leecalcote/istio-service-mesh-workshop](https://github.com/leecalcote/istio-service-mesh-workshop)

* [https://github.com/retroryan/istio-workshop](https://github.com/retroryan/istio-workshop)

* [https://eksworkshop.com/servicemesh/](https://eksworkshop.com/servicemesh/)
