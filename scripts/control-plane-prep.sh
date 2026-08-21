#!/bin/bash

set -e

echo "=============================================="
echo " Kubernetes Control Plane Preparation"
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
# Get AWS Private IP and Public IP
# --------------------------------------------------

echo
echo "[INFO] Detecting AWS instance IP addresses..."

TOKEN=$(curl -sS -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

PRIVATE_IP=$(curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

PUBLIC_IP=$(curl -sS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

if [[ -z "$PRIVATE_IP" ]]; then
    echo "[ERROR] Could not determine private IP."
    exit 1
fi

if [[ -z "$PUBLIC_IP" ]]; then
    echo "[ERROR] Could not determine public IP."
    exit 1
fi

echo
echo "----------------------------------------------"
echo " Private IP : $PRIVATE_IP"
echo " Public IP  : $PUBLIC_IP"
echo "----------------------------------------------"

# --------------------------------------------------
# Disable Swap
# --------------------------------------------------

echo
echo "[1/7] Disabling swap..."

sudo swapoff -a

sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "[OK] Swap disabled."

# --------------------------------------------------
# Load kernel modules
# --------------------------------------------------

echo
echo "[2/7] Configuring kernel modules..."

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
echo "[3/7] Configuring sysctl parameters..."

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
echo "[4/7] Installing containerd..."

cd /tmp

curl -LO \
  https://github.com/containerd/containerd/releases/download/v1.7.14/containerd-1.7.14-linux-amd64.tar.gz

sudo tar Cxzvf /usr/local \
  containerd-1.7.14-linux-amd64.tar.gz

curl -LO \
  https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

sudo mkdir -p /usr/local/lib/systemd/system/

sudo mv containerd.service \
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
echo "[5/7] Installing runc..."

cd /tmp

curl -LO \
  https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64

sudo install -m 755 runc.amd64 /usr/local/sbin/runc

echo "[OK] runc installed."

# --------------------------------------------------
# Install CNI plugins
# --------------------------------------------------

echo
echo "[6/7] Installing CNI plugins..."

cd /tmp

curl -LO \
  https://github.com/containernetworking/plugins/releases/download/v1.5.0/cni-plugins-linux-amd64-v1.5.0.tgz

sudo mkdir -p /opt/cni/bin

sudo tar Cxzvf \
  /opt/cni/bin \
  cni-plugins-linux-amd64-v1.5.0.tgz

echo "[OK] CNI plugins installed."

# --------------------------------------------------
# Install Kubernetes
# --------------------------------------------------

echo
echo "[7/7] Installing Kubernetes components..."

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
# Kubernetes Control Plane Initialization
# --------------------------------------------------

echo
echo "=============================================="
echo " Kubernetes Control Plane Initialization"
echo "=============================================="

echo
echo "[INFO] The following values will be used:"
echo
echo "Private IP : $PRIVATE_IP"
echo "Public IP  : $PUBLIC_IP"
echo "Node Name  : master"
echo "Pod CIDR   : 192.168.0.0/16"
echo

read -p "Continue with kubeadm init? [y/N]: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo
    echo "[INFO] kubeadm init cancelled."
    echo "[INFO] All server preparation steps have been completed."
    exit 0
fi

sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address="$PRIVATE_IP" \
  --apiserver-cert-extra-sans="$PUBLIC_IP" \
  --node-name=master

# --------------------------------------------------
# Configure kubectl
# --------------------------------------------------

echo
echo "[INFO] Configuring kubectl for current user..."

mkdir -p "$HOME/.kube"

sudo cp -i \
  /etc/kubernetes/admin.conf \
  "$HOME/.kube/config"

sudo chown \
  "$(id -u):$(id -g)" \
  "$HOME/.kube/config"

echo "[OK] kubectl configured."

# --------------------------------------------------
# Install Calico
# --------------------------------------------------

echo
echo "=============================================="
echo " Installing Calico CNI"
echo "=============================================="

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

echo
echo "[INFO] Downloading Calico custom resources..."

cd "$HOME"

curl -O \
  https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml

echo
echo "[INFO] Applying Calico custom resources..."

kubectl apply -f custom-resources.yaml

# --------------------------------------------------
# Final verification
# --------------------------------------------------

echo
echo "=============================================="
echo " Control Plane Setup Completed"
echo "=============================================="

echo
echo "[INFO] Kubernetes nodes:"
kubectl get nodes

echo
echo "[INFO] Kubernetes pods:"
kubectl get pods -A

echo
echo "=============================================="
echo " IMPORTANT"
echo "=============================================="
echo
echo "Private IP : $PRIVATE_IP"
echo "Public IP  : $PUBLIC_IP"
echo
echo "Use the kubeadm join command displayed"
echo "during kubeadm init to join the worker nodes."
echo
