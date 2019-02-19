#!/bin/bash -eux

minikube_install() {
  # Download minikube.
  curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/

  # Star minikube.
  export CHANGE_MINIKUBE_NONE_USER=true
  sudo --preserve-env minikube start --vm-driver=none --kubernetes-version=${KUBERNETES_VERSION}

  # Fix the kubectl context, as it's often stale.
  minikube update-context

  # Wait for Kubernetes to be up and ready.
  JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'; until kubectl get nodes -o jsonpath="$JSONPATH" 2>&1 | grep -q "Ready=True"; do sleep 1; done
}

kind_install() {
  curl -s https://storage.googleapis.com/golang/getgo/installer_linux --output installer_linux
  chmod +x installer_linux
  ./installer_linux
  export GOROOT=$HOME/.go
  export GOPATH=$HOME/go
  export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
  go get sigs.k8s.io/kind
  kind create cluster
  export KUBECONFIG="$(kind get kubeconfig-path)"
}

kubeadm-dind-cluster_install() {
  curl -Ls https://github.com/kubernetes-sigs/kubeadm-dind-cluster/releases/download/v0.1.0/dind-cluster-v1.13.sh --output dind-cluster.sh
  chmod +x dind-cluster.sh

  # start the cluster
  ./dind-cluster.sh up

  # add kubectl directory to PATH
  export PATH="$HOME/.kubeadm-dind-cluster:$PATH"
}

export TERM=linux
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update -qq
sudo --preserve-env apt-get install -qq -y curl ebtables jq pv siege socat unzip > /dev/null
which docker || sudo apt-get install -qq -y docker.io > /dev/null # Appveyor workaround - docker.io will replace installed docker-ce
sudo -E which npm || sudo apt-get install -qq -y npm > /dev/null  # Appveyor workaround - npm can not be installed there

# Install Terraform
export TERRAFORM_LATEST_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')
curl --silent --location https://releases.hashicorp.com/terraform/${TERRAFORM_LATEST_VERSION}/terraform_${TERRAFORM_LATEST_VERSION}_linux_amd64.zip --output /tmp/terraform_linux_amd64.zip
sudo unzip -q -o /tmp/terraform_linux_amd64.zip -d /usr/local/bin/

# Install markdownlint and markdown-link-check
sudo -E npm install -g markdownlint-cli markdown-link-check > /dev/null

# Markdown check
echo '"line-length": false' > /tmp/markdownlint_config.json
markdownlint -c /tmp/markdownlint_config.json README.md

# Link Checks
echo '{ "ignorePatterns": [ { "pattern": "^(http|https)://localhost" } ] }' > /tmp/config.json
markdown-link-check --quiet --config /tmp/config.json ./README.md

# Generate ssh key if needed
test -f $HOME/.ssh/id_rsa || ( install -m 0700 -d $HOME/.ssh && ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -q -N "" )

# Terraform checks
cat > terraform.tfvars << EOF
openstack_instance_image_name  = "test"
openstack_password             = "test"
openstack_tenant_name          = "test"
openstack_user_domain_name     = "test"
openstack_user_name            = "test"
openstack_auth_url             = "test"
openstack_instance_flavor_name = "test"
EOF

terraform init     -var-file=terraform.tfvars terrafrom/openstack
terraform validate -var-file=terraform.tfvars terrafrom/openstack

sudo swapoff -a

# Find out latest kubernetes version
export KUBERNETES_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)

# Download kubectl, which is a requirement for using minikube.
curl -sLo kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Start kubernetes
#minikube_install
#kind_install
kubeadm-dind-cluster_install
kubectl cluster-info

# k8s commands (use everything starting from Helm installation 'curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash')
sed -n '/^```bash$/,/^```$/p' README.md | sed '/^```*/d' | sed -n '/^curl -s https:\/\/raw.githubusercontent.com\/helm\/helm\/master\/scripts\/get | bash/,$p' > README.sh
source ./README.sh

# Istio cleanup
helm del --purge istio
kubectl -n istio-system delete job --all
kubectl delete -f install/kubernetes/helm/istio/templates/crds.yaml -n istio-system
kubectl delete namespace istio-system
kubectl label namespace default istio-injection-

cd ../..
rm -rf files

#export PROMPT_TIMEOUT=1
#./run-k8s-istio-demo.sh
