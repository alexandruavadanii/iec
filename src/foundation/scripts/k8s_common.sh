#!/bin/bash -ex

if grep -q -e rhel /etc/*-release; then
  OS_ID_LIKE=rhel
elif grep -q -e debian /etc/*-release; then
  OS_ID_LIKE=debian
fi

case ${OS_ID_LIKE:-} in
debian)
  DOCKER_VERSION=18.06.1~ce~3-0~ubuntu
  KUBE_VERSION=1.13.0-00
  K8S_CNI_VERSION=0.6.0-00
  KUBELET_CFG=/etc/default/kubelet
  ;;
rhel)
  DOCKER_VERSION=18.06.1.ce-3.el7
  KUBE_VERSION=1.13.0-0
  K8S_CNI_VERSION=0.6.0-0
  KUBELET_CFG=/etc/sysconfig/kubelet
  ;;
*)
  echo 'Unsupported distribution detected!'
  exit 1
  ;;
esac

case ${OS_ID_LIKE:-} in
debian)
  # Install basic software
  echo "Acquire::ForceIPv4 \"true\";" | sudo tee -a /etc/apt/apt.conf.d/99force-ipv4 > /dev/null
  sudo apt update
  sudo apt install -y software-properties-common apt-transport-https curl

  # Install Docker as Prerequisite
  curl -4fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo apt-key fingerprint 0EBFCD88
  sudo add-apt-repository \
    "deb https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  sudo apt update
  sudo apt install -y docker-ce=${DOCKER_VERSION}
  ;;
rhel)
  sudo yum install -y yum-utils device-mapper-persistent-data lvm2
  sudo yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install -y \
    docker-ce-$DOCKER_VERSION \
    docker-ce-cli-$DOCKER_VERSION \
    containerd.io
  ;;
esac

# Disable swap on your machine
sudo swapoff -a

case ${OS_ID_LIKE:-} in
debian)
  # Install Kubernetes with Kubeadm
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

  cat <<-EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
  sudo apt update
  # Minor fix for broken kubernetes-cni dependency in upstream xenial repo
  sudo apt install -y \
    kubernetes-cni=${K8S_CNI_VERSION} kubelet=${KUBE_VERSION} \
    kubeadm=${KUBE_VERSION} kubectl=${KUBE_VERSION}
  sudo apt-mark hold kubernetes-cni kubelet kubeadm kubectl
  ;;
rhel)
  cat <<-EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-$(uname -m)
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  sudo yum install -y kubelet-$KUBE_VERSION kubeadm-$KUBE_VERSION \
                      kubectl-$KUBE_VERSION kubernetes-cni-$K8S_CNI_VERSION
  ;;
esac

# Add extra flags to Kubelet
if ! grep -q -e 'fail-swap-on' $KUBELET_CFG; then
  sudo sed 's/KUBELET_EXTRA_ARGS=/KUBELET_EXTRA_ARGS=--fail-swap-on=false --feature-gates HugePages=false/' -i $KUBELET_CFG
fi

sudo systemctl enable docker kubelet
sudo systemctl restart docker kubelet

sudo modprobe br_netfilter
_conf='/etc/sysctl.d/99-akraino-iec.conf'
echo 'net.bridge.bridge-nf-call-iptables = 1' |& sudo tee "${_conf}"
sudo sysctl -q -p "${_conf}"
