#!/bin/bash -ex

# For host setup as Kubernetes master
MGMT_IP=$1
POD_NETWORK_CIDR=${2:-192.168.0.0/16}
SERVICE_CIDR=${3:-172.16.1.0/24}

if [ -z "${MGMT_IP}" ]; then
  echo "Please specify a management IP!"
  exit 1
fi

if ! kubectl get nodes; then
  sudo kubeadm config images pull
  sudo kubeadm init \
    --pod-network-cidr="${POD_NETWORK_CIDR}" \
    --apiserver-advertise-address="${MGMT_IP}" \
    --service-cidr="${SERVICE_CIDR}"

  if [ "$(id -u)" = 0 ]; then
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" | \
      tee -a "${HOME}/.profile"
    # shellcheck disable=SC1090
    source "${HOME}/.profile"
  else
    mkdir -p "${HOME}/.kube"
    sudo cp -i /etc/kubernetes/admin.conf "${HOME}/.kube/config"
    sudo chown "$(id -u)":"$(id -g)" "${HOME}/.kube/config"
  fi
fi
