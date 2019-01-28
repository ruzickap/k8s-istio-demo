# Kubernetes with Istio running on top of OpenStack demo

Find below few commands showing basics of Istio...

[TOC]

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
terraform apply -auto-approve -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
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
    172.16.240.185,
    172.16.242.218,
    172.16.240.44
]
```

At the end of the output you should see 3 IP addresses which should be accessible by ssh using your public key (~/.ssh/id_rsa.pub).

## Install k8s

Install k8s using kubeadm to the provisioned VMs.

```bash
./install-k8s-kubeadm.sh
```

Check if all nodes are up.

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
kubectl get pods -l app=helm --all-namespaces
```

Output:

```shell
NAMESPACE     NAME                            READY     STATUS    RESTARTS   AGE
kube-system   tiller-deploy-dbb85cb99-hhxrt   1/1       Running   0          35s
```

## Instal Rook

Install Rook Operator (Ceph storage for k8s).

```bash
helm repo add rook-stable https://charts.rook.io/stable
helm install --wait --name rook-ceph --namespace rook-ceph-system rook-stable/rook-ceph
sleep 5
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

Create your Rook cluster.

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml
sleep 200
```

Check what was created in `rook-ceph` namespace.

```bash
kubectl get svc,deploy,po --namespace=rook-ceph -o wide
```

Output:

```shell
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE       SELECTOR
service/rook-ceph-mgr             ClusterIP   10.103.130.126   <none>        9283/TCP   57s       app=rook-ceph-mgr,rook_cluster=rook-ceph
service/rook-ceph-mgr-dashboard   ClusterIP   10.108.113.191   <none>        8443/TCP   57s       app=rook-ceph-mgr,rook_cluster=rook-ceph
service/rook-ceph-mon-a           ClusterIP   10.109.40.168    <none>        6790/TCP   4m        app=rook-ceph-mon,ceph_daemon_id=a,mon=a,mon_cluster=rook-ceph,rook_cluster=rook-ceph
service/rook-ceph-mon-b           ClusterIP   10.103.75.150    <none>        6790/TCP   3m        app=rook-ceph-mon,ceph_daemon_id=b,mon=b,mon_cluster=rook-ceph,rook_cluster=rook-ceph
service/rook-ceph-mon-c           ClusterIP   10.96.51.185     <none>        6790/TCP   3m        app=rook-ceph-mon,ceph_daemon_id=c,mon=c,mon_cluster=rook-ceph,rook_cluster=rook-ceph

NAME                                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS   IMAGES          SELECTOR
deployment.extensions/rook-ceph-mgr-a   1         1         1            1           1m        mgr          ceph/ceph:v13   app=rook-ceph-mgr,ceph_daemon_id=a,instance=a,mgr=a,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-mon-a   1         1         1            1           4m        mon          ceph/ceph:v13   app=rook-ceph-mon,ceph_daemon_id=a,mon=a,mon_cluster=rook-ceph,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-mon-b   1         1         1            1           3m        mon          ceph/ceph:v13   app=rook-ceph-mon,ceph_daemon_id=b,mon=b,mon_cluster=rook-ceph,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-mon-c   1         1         1            1           3m        mon          ceph/ceph:v13   app=rook-ceph-mon,ceph_daemon_id=c,mon=c,mon_cluster=rook-ceph,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-osd-0   1         1         1            1           44s       osd          ceph/ceph:v13   app=rook-ceph-osd,ceph-osd-id=0,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-osd-1   1         1         1            1           44s       osd          ceph/ceph:v13   app=rook-ceph-osd,ceph-osd-id=1,rook_cluster=rook-ceph
deployment.extensions/rook-ceph-osd-2   1         1         1            1           43s       osd          ceph/ceph:v13   app=rook-ceph-osd,ceph-osd-id=2,rook_cluster=rook-ceph

NAME                                                             READY     STATUS      RESTARTS   AGE       IP           NODE
pod/rook-ceph-mgr-a-669f5b47fc-ptwcr                             1/1       Running     0          1m        10.244.2.5   pruzicka-k8s-istio-demo-node03
pod/rook-ceph-mon-a-798d774f55-nkmmr                             1/1       Running     0          4m        10.244.0.5   pruzicka-k8s-istio-demo-node01
pod/rook-ceph-mon-b-56dbd4f886-z9nbj                             1/1       Running     0          3m        10.244.1.6   pruzicka-k8s-istio-demo-node02
pod/rook-ceph-mon-c-79d54b78f7-zd7zx                             1/1       Running     0          3m        10.244.2.4   pruzicka-k8s-istio-demo-node03
pod/rook-ceph-osd-0-57c5b499b6-p2fsl                             1/1       Running     0          44s       10.244.1.8   pruzicka-k8s-istio-demo-node02
pod/rook-ceph-osd-1-7ddbfbfb5f-qrdzx                             1/1       Running     0          44s       10.244.0.7   pruzicka-k8s-istio-demo-node01
pod/rook-ceph-osd-2-66c4d8969c-tt4k9                             1/1       Running     0          43s       10.244.2.7   pruzicka-k8s-istio-demo-node03
pod/rook-ceph-osd-prepare-pruzicka-k8s-istio-demo-node01-ffsrp   0/2       Completed   0          49s       10.244.0.6   pruzicka-k8s-istio-demo-node01
pod/rook-ceph-osd-prepare-pruzicka-k8s-istio-demo-node02-65mnz   0/2       Completed   0          49s       10.244.1.7   pruzicka-k8s-istio-demo-node02
pod/rook-ceph-osd-prepare-pruzicka-k8s-istio-demo-node03-kz857   0/2       Completed   0          49s       10.244.2.6   pruzicka-k8s-istio-demo-node03
```

Get the Toolbox with ceph commands.

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/toolbox.yaml
sleep 5
```

The deployment with `rook-ceph-tools` was created.

```bash
kubectl get deploy,po --namespace=rook-ceph -o wide -l app=rook-ceph-tools
```

Output:

```shell
NAME                                    DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS        IMAGES             SELECTOR
deployment.extensions/rook-ceph-tools   1         1         1            1           11s       rook-ceph-tools   rook/ceph:master   app=rook-ceph-tools

NAME                                   READY     STATUS    RESTARTS   AGE       IP               NODE
pod/rook-ceph-tools-76c7d559b6-qth8c   1/1       Running   0          11s       192.168.250.12   pruzicka-k8s-istio-demo-node02
```

Create a storage class based on the Ceph RBD volume plugin.

```bash
kubectl create -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/storageclass.yaml
# Give Ceph some time to create pool...
sleep 20
```

Set `rook-ceph-block`

```bash
kubectl patch storageclass rook-ceph-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Check the storageclasses.

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

See the CephBlockPool.

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

Check the status of your Ceph installation.

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

Ceph status.

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

Check health detail of Ceph cluster.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph health detail
```

Output:

```shell
HEALTH_OK
```

Check monitor quorum status of Ceph.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph quorum_status --format json-pretty
```

Dump monitoring information from Ceph.

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

Check the cluster usage status.

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

Check OSD usage of Ceph.

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

Check the Ceph monitor.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph mon stat
```

Output:

```shell
e3: 3 mons at {a=10.109.40.168:6790/0,b=10.103.75.150:6790/0,c=10.96.51.185:6790/0}, election epoch 16, leader 0 c, quorum 0,1,2 c,b,a
```

Check OSD stats.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd stat
```

Output:

```shell
3 osds: 3 up, 3 in; epoch: e20
```

Check pool stats.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd pool stats
```

Output:

```shell
pool replicapool id 1
  nothing is going on
```

Check pg stats.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph pg stat
```

Output:

```shell
100 pgs: 100 active+clean; 0 B data, 13 GiB used, 44 GiB / 58 GiB avail
```

List the Ceph pools in detail.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph osd pool ls detail
```

Output:

```shell
pool 1 'replicapool' replicated size 1 min_size 1 crush_rule 1 object_hash rjenkins pg_num 100 pgp_num 100 last_change 20 flags hashpspool stripe_width 0 application rbd
```

Check the CRUSH map view of OSDs.

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

List the cluster authentication keys.

```bash
kubectl -n rook-ceph exec $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- ceph auth list
```

## Install ElasticSearch, Kibana, Fluentbit

Add ElasticSearch operator to helm.

```bash
helm repo add es-operator https://raw.githubusercontent.com/upmc-enterprises/elasticsearch-operator/master/charts/
```

Install ElasticSearch operator.

```bash
helm install --wait --name elasticsearch-operator es-operator/elasticsearch-operator --set rbac.enabled=True --namespace es-operator
sleep 20
```

Check how the operator looks like.

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

Install ElasticSearch cluster.

```bash
helm install --wait --name=elasticsearch --namespace logging es-operator/elasticsearch \
  --set kibana.enabled=true \
  --set cerebro.enabled=true \
  --set storage.class=rook-ceph-block \
  --set clientReplicas=3,masterReplicas=3,dataReplicas=3
sleep 400
```

Show ElasticSearch components.

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

List provisioned ElasticSearch clusters.

```bash
kubectl get elasticsearchclusters --all-namespaces
```

Output:

```shell
NAMESPACE   NAME                    AGE
logging     elasticsearch-cluster   7m
```

Install Fluentbit.

```bash
helm install --wait stable/fluent-bit --name=fluent-bit --namespace=logging \
  --set metrics.enabled=true \
  --set backend.type=es \
  --set backend.es.host=elasticsearch-elasticsearch-cluster \
  --set backend.es.tls=on \
  --set backend.es.tls_verify=off
```

## Install Istio

Either download Istio directly from [https://github.com/istio/istio/releases](https://github.com/istio/istio/releases) or get the latest version by using curl.

```bash
test -d files || mkdir files
cd files
curl -L https://git.io/getLatestIstio | sh -
```

Change the directory to the Istio installation files location.

```bash
cd istio*
```

Install Istio using helm.

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

See the istio components.

```bash
kubectl get --namespace=istio-system svc,deployment,pods -o wide
```

Output

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

Configure Istio with a new log type and send those logs to the FluentD.

```bash
kubectl apply -f ../../yaml/fluentd-istio.yaml
```

## Istio example

Let the default namespace to use istio injection.

```bash
kubectl label namespace default istio-injection=enabled
```

Check namespaces.

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
service/details       ClusterIP   10.107.118.4     <none>        9080/TCP   5m        app=details
service/kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP    46m       <none>
service/productpage   ClusterIP   10.109.95.3      <none>        9080/TCP   5m        app=productpage
service/ratings       ClusterIP   10.100.134.207   <none>        9080/TCP   5m        app=ratings
service/reviews       ClusterIP   10.97.112.16     <none>        9080/TCP   5m        app=reviews

NAME                                   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS    IMAGES                                         SELECTOR
deployment.extensions/details-v1       1         1         1            1           5m        details       istio/examples-bookinfo-details-v1:1.8.0       app=details,version=v1
deployment.extensions/productpage-v1   1         1         1            1           5m        productpage   istio/examples-bookinfo-productpage-v1:1.8.0   app=productpage,version=v1
deployment.extensions/ratings-v1       1         1         1            1           5m        ratings       istio/examples-bookinfo-ratings-v1:1.8.0       app=ratings,version=v1
deployment.extensions/reviews-v1       1         1         1            1           5m        reviews       istio/examples-bookinfo-reviews-v1:1.8.0       app=reviews,version=v1
deployment.extensions/reviews-v2       1         1         1            1           5m        reviews       istio/examples-bookinfo-reviews-v2:1.8.0       app=reviews,version=v2
deployment.extensions/reviews-v3       1         1         1            1           5m        reviews       istio/examples-bookinfo-reviews-v3:1.8.0       app=reviews,version=v3

NAME                                      READY     STATUS    RESTARTS   AGE       IP            NODE
pod/details-v1-68c7c8666d-td6b7           2/2       Running   0          5m        10.244.1.25   pruzicka-k8s-istio-demo-node02
pod/elasticsearch-operator-sysctl-86zdw   1/1       Running   0          28m       10.244.1.9    pruzicka-k8s-istio-demo-node02
pod/elasticsearch-operator-sysctl-rmhg4   1/1       Running   0          28m       10.244.0.8    pruzicka-k8s-istio-demo-node01
pod/elasticsearch-operator-sysctl-rptxf   1/1       Running   0          28m       10.244.2.9    pruzicka-k8s-istio-demo-node03
pod/productpage-v1-54d799c966-hghsz       2/2       Running   0          5m        10.244.1.27   pruzicka-k8s-istio-demo-node02
pod/ratings-v1-8558d4458d-vfrh4           2/2       Running   0          5m        10.244.2.19   pruzicka-k8s-istio-demo-node03
pod/reviews-v1-cb8655c75-68shr            2/2       Running   0          5m        10.244.1.26   pruzicka-k8s-istio-demo-node02
pod/reviews-v2-7fc9bb6dcf-6d252           2/2       Running   0          5m        10.244.0.13   pruzicka-k8s-istio-demo-node01
pod/reviews-v3-c995979bc-vrnbg            2/2       Running   0          5m        10.244.2.20   pruzicka-k8s-istio-demo-node03

NAME                                           AGE
gateway.networking.istio.io/bookinfo-gateway   5m

NAME                                          AGE
virtualservice.networking.istio.io/bookinfo   5m
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
31380 | 31390 | 172.16.240.185 | 172.16.240.185:31380
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
kubectl -n logging port-forward $(kubectl -n logging get pod -l role=kibana -o jsonpath='{.items[0].metadata.name}') 5601:5601 &
```

* Cerbero

```bash
kubectl -n logging port-forward $(kubectl -n logging get pod -l role=cerebro -o jsonpath='{.items[0].metadata.name}') 9000:9000 &
```

Link: [http://localhost:9000](http://localhost:9000)

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
