#!/bin/bash -ex

# For host setup as Kubernetes master
MGMT_IP=$1
POD_NETWORK_CIDR=${2:-192.168.0.0/16}
SERVICE_CIDR=${3:-172.16.1.0/24}
KUBEADM_CFG="$(dirname "$0")/kubeadm.yaml"

export MGMT_IP POD_NETWORK_CIDR SERVICE_CIDR

if [ -z "${MGMT_IP}" ]; then
  echo "Please specify a management IP!"
  exit 1
fi

if ! kubectl get nodes; then
  sudo kubeadm config images pull
  envsubst < "${KUBEADM_CFG}.tmpl" > "${KUBEADM_CFG}"
  sudo kubeadm init --config "${KUBEADM_CFG}"

  if [ "$(id -u)" = 0 ]; then
    echo "export KUBECONFIG=/etc/kubernetes/admin.conf" | \
      tee -a "${HOME}/.bashrc"
    # shellcheck disable=SC1090
    source "${HOME}/.bashrc"
  fi

  mkdir -p "${HOME}/.kube"
  sudo cp /etc/kubernetes/admin.conf "${HOME}/.kube/config"
  sudo chown "$(id -u)":"$(id -g)" "${HOME}/.kube/config"

  sleep 5
  sudo swapon -a
fi
