#!/bin/bash -eu

MYUSER="ubuntu"
SSH_ARGS="-o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
POD_NETWORK_CIDR="10.244.0.0/16"
KUBERNETES_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | tr -d v)
CNI_URL="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

INSTALL_KUBERNETES="
export DEBIAN_FRONTEND='noninteractive'
apt-get update -qq && apt-get install -y -qq apt-transport-https curl > /dev/null
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat > /etc/apt/sources.list.d/kubernetes.list << EOF2
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF2
apt-get update -qq
apt-get install -y -qq --no-install-recommends chrony docker.io kubelet=${KUBERNETES_VERSION}-00 kubeadm=${KUBERNETES_VERSION}-00 kubectl=${KUBERNETES_VERSION}-00 > /dev/null
systemctl enable docker.service
"

echo "# Set IPs form VMs and store them into variables"
NODE_IP[0]=`terraform output -json | jq -r '.vms_public_ip.value[0]'`
NODE_IP[1]=`terraform output -json | jq -r '.vms_public_ip.value[1]'`
NODE_IP[2]=`terraform output -json | jq -r '.vms_public_ip.value[2]'`


echo "# Fill the /etc/hosts on each cluster node"
for NODE in ${NODE_IP[*]}; do
  echo "# ${NODE}"
  ssh -t ${MYUSER}@$NODE ${SSH_ARGS} "sudo /bin/bash -c '
    sed -i \"s/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/\" /etc/sysctl.d/99-sysctl.conf
    sysctl --quiet --system
    cat >> /etc/hosts << EOF2
${NODE_IP[0]} node1 node1.cluster.local
${NODE_IP[1]} node2 node2.cluster.local
${NODE_IP[2]} node3 node3.cluster.local
EOF2
'" && echo "# Done..."
done

echo "# Install kubernetes Master (${MYUSER}@${NODE_IP[0]})"
ssh -t ${MYUSER}@${NODE_IP[0]} ${SSH_ARGS} "sudo /bin/bash -cx '
$INSTALL_KUBERNETES

kubeadm init --apiserver-cert-extra-sans=${NODE_IP[0]},${NODE_IP[1]},${NODE_IP[2]} --pod-network-cidr=$POD_NETWORK_CIDR --kubernetes-version v${KUBERNETES_VERSION}

test -d /home/$MYUSER/.kube || mkdir /home/$MYUSER/.kube
cp -i /etc/kubernetes/admin.conf /home/$MYUSER/.kube/config
chown -R $MYUSER:$MYUSER /home/$MYUSER/.kube

export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl apply -f $CNI_URL
'"

echo "# Create bootstrap token command using: ssh ${MYUSER}@${NODE_IP[0]} \"sudo kubeadm token create --print-join-command\""
KUBEADM_TOKEN_COMMAND=`ssh -t ${MYUSER}@${NODE_IP[0]} ${SSH_ARGS} "sudo kubeadm token create --print-join-command"`

echo "# Install Kubernetes packages to all nodes and join the nodes to the master using bootstrap token"
test -f nohup.out && rm nohup.out
for NODE in ${NODE_IP[1]} ${NODE_IP[2]}; do
  echo "*** $NODE"
  nohup ssh -t ${MYUSER}@$NODE ${SSH_ARGS} "sudo /bin/bash -cx '
$INSTALL_KUBERNETES > /dev/null
hostname
$KUBEADM_TOKEN_COMMAND
'" &
done

echo "# Copy the kubeconfig to the local machine and get some basic details about kuberenetes cluster"
ssh ${SSH_ARGS} ${MYUSER}@${NODE_IP[0]} "cat ~/.kube/config" | sed "s@    server: https://.*@    server: https://${NODE_IP[0]}:6443@" > kubeconfig.conf

export KUBECONFIG=$PWD/kubeconfig.conf
kubectl get nodes

echo "*** Allow pods to be scheduled on the masters"
kubectl taint nodes --all node-role.kubernetes.io/master-

cat << \EOF
*** Wait few minutes for the worker nodes to join..."
*** Start with:
export KUBECONFIG=$PWD/kubeconfig.conf
kubectl get nodes
EOF
