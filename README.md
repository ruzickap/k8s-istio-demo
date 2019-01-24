# Kubernetes with Istio running on top of OpenStack demo

Find below few commands showing basics of Istio...

## Requirements

* [Docker](https://www.docker.com/) or [Podman](https://podman.io/)
* [Ansible](https://www.ansible.com/)
* [Terraform](https://www.terraform.io/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (kubernetes-client package)

## Provision VMs in OpenStack

Start 3 VMs (one master and 2 workers) where the k8s will be installed.

```
git clone https://github.com/ruzickap/k8s-istio-demo
cd k8s-istio-demo

# Modify the terraform variable file if needed
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

terraform init -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
terraform apply -var-file=terrafrom/openstack/terraform.tfvars terrafrom/openstack
```

At the end of the output you should see 3 IP addresses which should be accessible by ssh using your public key (~/.ssh/id_rsa.pub)

## Install k8s

Install k8s using kubeadm.

```
./install-k8s-kubeadm.sh
```

## Install helm

Install helm (tiller) to k8s cluster

```
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --wait --service-account tiller
helm repo update
```
