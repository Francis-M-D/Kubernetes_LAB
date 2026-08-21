#!/bin/bash

set -e

echo "=============================================="
echo " Kubernetes Worker Node Preparation"
echo "=============================================="

# --------------------------------------------------
# Basic information
# --------------------------------------------------

echo
echo "[INFO] Hostname:"
hostname

echo
echo "[INFO] OS:"
cat /etc/os-release | grep PRETTY_NAME

# --------------------------------------------------
# Disable Swap
# --------------------------------------------------

echo
echo "[1/6] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[OK] Swap disabled."

# --------------------------------------------------
# Load kernel modules
# --------------------------------------------------

echo
echo "[2/6] Configuring kernel modules..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "[OK] Kernel modules loaded."

# --------------------------------------------------
# Configure sysctl
# --------------------------------------------------

echo
echo "[3/6] Configuring sysctl parameters..."

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo
echo "[INFO] Verifying kernel modules..."

lsmod | grep br_netfilter || true
lsmod | grep overlay || true

echo
echo "[INFO] Verifying sysctl parameters..."

sysctl \
  net.bridge.bridge-nf-call-iptables \
  net.bridge.bridge-nf-call-ip6tables \
  net.ipv4.ip_forward

# --------------------------------------------------
# Install containerd
# --------------------------------------------------

echo
echo "[4/6] Installing containerd..."

cd /tmp

curl -LO \
  https://github.com/containerd/containerd/releases/download/v1.7.14/containerd-1.7.14-linux-amd64.tar.gz

sudo tar Cxzvf \
  /usr/local \
  containerd-1.7.14-linux-amd64.tar.gz

curl -LO \
  https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

sudo mkdir -p /usr/local/lib/systemd/system/

sudo mv \
  containerd.service \
  /usr/local/lib/systemd/system/

sudo mkdir -p /etc/containerd

containerd config default | \
  sudo tee /etc/containerd/config.toml

sudo sed -i \
  's/SystemdCgroup = false/SystemdCgroup = true/g' \
  /etc/containerd/config.toml

sudo systemctl daemon-reload
sudo systemctl enable --now containerd

echo
echo "[INFO] Containerd status:"
sudo systemctl --no-pager status containerd

# --------------------------------------------------
# Install runc
# --------------------------------------------------

echo
echo "[5/6] Installing runc..."

cd /tmp

curl -LO \
  https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64

sudo install -m 755 \
  runc.amd64 \
  /usr/local/sbin/runc

echo "[OK] runc installed."

# --------------------------------------------------
# Install CNI plugins
# --------------------------------------------------

echo
echo "[INFO] Installing CNI plugins..."

curl -LO \
  https://github.com/containernetworking/plugins/releases/download/v1.5.0/cni-plugins-linux-amd64-v1.5.0.tgz

sudo mkdir -p /opt/cni/bin

sudo tar Cxzvf \
  /opt/cni/bin \
  cni-plugins-linux-amd64-v1.5.0.tgz

echo "[OK] CNI plugins installed."

# --------------------------------------------------
# Kubernetes
# --------------------------------------------------

echo
echo "[6/6] Installing Kubernetes components..."

sudo apt-get update

sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gpg

sudo mkdir -p /etc/apt/keyrings

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  sudo gpg --dearmor \
  -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

sudo apt-get install -y \
  kubelet=1.29.6-1.1 \
  kubeadm=1.29.6-1.1 \
  kubectl=1.29.6-1.1 \
  --allow-downgrades \
  --allow-change-held-packages

sudo apt-mark hold kubelet kubeadm kubectl

echo
echo "[INFO] Kubernetes versions:"

kubeadm version
kubelet --version
kubectl version --client

# --------------------------------------------------
# Configure containerd socket
# --------------------------------------------------

echo
echo "[INFO] Configuring containerd socket permissions..."

sudo chmod 666 /var/run/containerd/containerd.sock

# --------------------------------------------------
# Configure crictl
# --------------------------------------------------

echo
echo "[INFO] Configuring crictl..."

if command -v crictl >/dev/null 2>&1; then

    sudo crictl config \
      --set runtime-endpoint=unix:///run/containerd/containerd.sock \
      --set image-endpoint=unix:///run/containerd/containerd.sock

else

    echo "[WARNING] crictl is not installed."
    echo "[WARNING] Skipping crictl configuration."

fi

# --------------------------------------------------
# Final verification
# --------------------------------------------------

echo
echo "=============================================="
echo " Worker Node Preparation Completed"
echo "=============================================="

echo
echo "[INFO] Containerd:"
sudo systemctl is-active containerd

echo
echo "[INFO] Kubernetes:"
kubeadm version
kubelet --version
kubectl version --client

echo
echo "=============================================="
echo " NEXT STEP"
echo "=============================================="
echo
echo "Run the kubeadm join command generated by"
echo "the control plane on this worker node."
echo
