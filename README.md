# Kubernetes 3-Node Lab on AWS

A hands-on Kubernetes laboratory environment provisioned on AWS using Terraform.

This project creates a three-node Kubernetes cluster consisting of one control plane and two worker nodes. The AWS infrastructure is provisioned using Terraform, while Bash scripts prepare the EC2 instances for Kubernetes.

The Kubernetes cluster is initialized using `kubeadm` and uses `containerd` as the container runtime and Calico as the CNI.

---

## Table of Contents

* [Architecture](#architecture)
* [Project Structure](#project-structure)
* [Environment Specifications](#environment-specifications)
* [Kubernetes Components](#kubernetes-components)
* [Prerequisites](#prerequisites)
* [1. Configure AWS](#1-configure-aws)
* [2. Provision Infrastructure](#2-provision-infrastructure)
* [3. Prepare the Control Plane](#3-prepare-the-control-plane)
* [4. Prepare the Worker Nodes](#4-prepare-the-worker-nodes)
* [5. Join Worker Nodes](#5-join-worker-nodes)
* [6. Verify the Cluster](#6-verify-the-cluster)
* [7. Deploy a Test Application](#7-deploy-a-test-application)
* [Networking](#networking)
* [Security Groups](#security-groups)
* [IP Address Handling](#ip-address-handling)
* [Troubleshooting](#troubleshooting)
* [Cleanup](#cleanup)
* [GitHub Security](#github-security)
* [Learning Flow](#learning-flow)

---

## Architecture

```text
                                Internet
                                    |
                                    |
                           Internet Gateway
                                    |
                    +---------------+---------------+
                    |                               |
                    |          AWS VPC              |
                    |       172.31.0.0/16           |
                    |                               |
                    |       Public Subnet           |
                    |       172.31.1.0/24           |
                    |                               |
                    |   +-----------------------+   |
                    |   |    Control Plane      |   |
                    |   |       t3.small        |   |
                    |   |                       |   |
                    |   |  kube-apiserver       |   |
                    |   |  etcd                 |   |
                    |   |  scheduler            |   |
                    |   |  controller-manager   |   |
                    |   +-----------+-----------+   |
                    |               |               |
                    |               | Kubernetes    |
                    |               | Cluster       |
                    |               | Network       |
                    |        +------+-------+       |
                    |        |              |       |
                    |        v              v       |
                    |   +----------+  +----------+  |
                    |   | Worker 1 |  | Worker 2 |  |
                    |   | t3.small |  | t3.small |  |
                    |   +----------+  +----------+  |
                    |                               |
                    +-------------------------------+
```

### Network Layout

```text
AWS VPC
172.31.0.0/16
│
└── Public Subnet
    172.31.1.0/24
    │
    ├── Control Plane
    │
    ├── Worker 1
    │
    └── Worker 2

Kubernetes Pod Network
192.168.0.0/16
```

---

## Project Structure

```text
.
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── scripts/
│   ├── control-plane-prep.sh
│   └── worker-prep.sh
│
├── .gitignore
└── README.md
```

### Terraform

The `terraform/` directory contains the AWS infrastructure configuration.

It provisions:

* VPC
* Public subnet
* Internet Gateway
* Public route table
* Control-plane security group
* Worker security group
* Control-plane EC2 instance
* Worker EC2 instances

### Scripts

The `scripts/` directory contains the server preparation scripts.

| Script                  | Purpose                                               |
| ----------------------- | ----------------------------------------------------- |
| `control-plane-prep.sh` | Prepares and initializes the Kubernetes control plane |
| `worker-prep.sh`        | Prepares a Kubernetes worker node                     |

---

## Environment Specifications

| Component        | Configuration           |
| ---------------- | ----------------------- |
| Cloud            | AWS                     |
| Region           | `ap-south-1`            |
| VPC CIDR         | `172.31.0.0/16`         |
| Public Subnet    | `172.31.1.0/24`         |
| Subnet Type      | Public                  |
| Internet Gateway | Enabled                 |
| EC2 Instances    | 3                       |
| Control Plane    | 1                       |
| Worker Nodes     | 2                       |
| Instance Type    | `t3.medium`             |
| Operating System | Ubuntu                  |
| AMI              | `ami-01a00762f46d584a1` |
| EC2 Key Pair     | `LinuxKey`              |
| Public IP        | Enabled                 |

---

## Kubernetes Components

| Component   | Version   |
| ----------- | --------- |
| Kubernetes  | `1.29.6`  |
| kubeadm     | `1.29.6`  |
| kubelet     | `1.29.6`  |
| kubectl     | `1.29.6`  |
| containerd  | `1.7.14`  |
| runc        | `1.1.12`  |
| CNI Plugins | `1.5.0`   |
| Calico      | `v3.28.0` |

> The versions are intentionally pinned to make the lab environment reproducible.

---

## Prerequisites

Before starting, ensure the following are available:

* AWS account
* AWS CLI
* Terraform
* Git
* SSH client
* AWS EC2 key pair named `LinuxKey`
* Corresponding private key for `LinuxKey`
* AWS credentials configured locally
* Access to the `ap-south-1` region

Verify AWS access:

```bash
aws sts get-caller-identity
```

Verify Terraform:

```bash
terraform version
```

Verify Git:

```bash
git --version
```

---

# 1. Configure AWS

Configure the AWS CLI:

```bash
aws configure
```

Use:

```text
AWS Access Key ID:     <YOUR_ACCESS_KEY>
AWS Secret Access Key: <YOUR_SECRET_KEY>
Default region name:   ap-south-1
Default output format: json
```

Verify the configured identity:

```bash
aws sts get-caller-identity
```

Do not commit AWS credentials to this repository.

---

# 2. Provision Infrastructure

Move into the Terraform directory:

```bash
cd terraform
```

Initialize Terraform:

```bash
terraform init
```

Format the configuration:

```bash
terraform fmt
```

Validate the configuration:

```bash
terraform validate
```

Expected result:

```text
Success! The configuration is valid.
```

Review the execution plan:

```bash
terraform plan
```

If the plan looks correct, provision the infrastructure:

```bash
terraform apply
```

Enter:

```text
yes
```

when Terraform asks for confirmation.

---

## Terraform Outputs

After the infrastructure has been created:

```bash
terraform output
```

The outputs include:

```text
control_plane_public_ip
control_plane_private_ip

worker_1_public_ip
worker_1_private_ip

worker_2_public_ip
worker_2_private_ip
```

These addresses will be used when connecting to the EC2 instances.

---

# 3. Prepare the Control Plane

Copy the control-plane script to the control-plane instance:

```bash
scp -i LinuxKey.pem \
  ../scripts/control-plane-prep.sh \
  ubuntu@<CONTROL_PLANE_PUBLIC_IP>:/home/ubuntu/
```

Connect to the control plane:

```bash
ssh -i LinuxKey.pem ubuntu@<CONTROL_PLANE_PUBLIC_IP>
```

Make the script executable:

```bash
chmod +x control-plane-prep.sh
```

Run the script:

```bash
./control-plane-prep.sh
```

The script performs the following operations:

1. Detects the EC2 private IP.
2. Detects the EC2 public IP.
3. Disables swap.
4. Loads `overlay` and `br_netfilter`.
5. Configures Kubernetes networking parameters.
6. Installs containerd.
7. Configures containerd to use `SystemdCgroup`.
8. Installs runc.
9. Installs CNI plugins.
10. Installs kubeadm, kubelet and kubectl.
11. Initializes the Kubernetes control plane.
12. Configures the local kubectl configuration.
13. Installs Calico.
14. Displays the cluster status.

---

## Control Plane Initialization

The script automatically determines the EC2 IP addresses.

The following values do not need to be manually edited:

```text
Private IP
Public IP
```

The script dynamically constructs the `kubeadm init` command:

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address="<PRIVATE_IP>" \
  --apiserver-cert-extra-sans="<PUBLIC_IP>" \
  --node-name=master
```

For example:

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address="172.31.x.x" \
  --apiserver-cert-extra-sans="13.x.x.x" \
  --node-name=master
```

The actual IP addresses will be determined automatically when the script runs.

---

# 4. Prepare the Worker Nodes

The worker preparation script must be executed on **both worker nodes**.

Copy the script to Worker 1:

```bash
scp -i LinuxKey.pem \
  ../scripts/worker-prep.sh \
  ubuntu@<WORKER_1_PUBLIC_IP>:/home/ubuntu/
```

Connect to Worker 1:

```bash
ssh -i LinuxKey.pem ubuntu@<WORKER_1_PUBLIC_IP>
```

Make the script executable:

```bash
chmod +x worker-prep.sh
```

Run:

```bash
./worker-prep.sh
```

Repeat the same process for Worker 2.

```bash
scp -i LinuxKey.pem \
  ../scripts/worker-prep.sh \
  ubuntu@<WORKER_2_PUBLIC_IP>:/home/ubuntu/
```

Then:

```bash
ssh -i LinuxKey.pem ubuntu@<WORKER_2_PUBLIC_IP>
```

Run:

```bash
chmod +x worker-prep.sh
./worker-prep.sh
```

---

## Worker Preparation Includes

The worker script performs:

```text
Disable Swap
      |
      v
Kernel Modules
      |
      v
Sysctl Configuration
      |
      v
containerd
      |
      v
runc
      |
      v
CNI Plugins
      |
      v
kubeadm + kubelet + kubectl
```

The worker script does **not** execute `kubeadm init`.

Workers must be joined to the cluster using the join command generated by the control plane.

---

# 5. Join Worker Nodes

After `kubeadm init` completes successfully on the control plane, it will display a command similar to:

```bash
sudo kubeadm join 172.31.71.210:6443 \
  --token xxxxx \
  --discovery-token-ca-cert-hash sha256:xxx
```

Copy the generated command.

Run it on **Worker 1**:

```bash
sudo kubeadm join <CONTROL_PLANE_PRIVATE_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

Run the same generated command on **Worker 2**.

> Do not use the example token or IP address shown above. Always use the command generated by your own control-plane node.

---

## Regenerate the Join Command

If the join command was not copied, connect to the control plane and run:

```bash
kubeadm token create --print-join-command
```

Example output:

```bash
kubeadm join 172.31.71.210:6443 \
  --token xxxxx \
  --discovery-token-ca-cert-hash sha256:xxx
```

Run the generated command on both worker nodes.

---

# 6. Verify the Cluster

Return to the control-plane node.

Check the cluster nodes:

```bash
kubectl get nodes
```

Expected result:

```text
NAME      STATUS   ROLES           AGE   VERSION
master    Ready    control-plane   ...   v1.29.6
worker1   Ready    <none>          ...   v1.29.6
worker2   Ready    <none>          ...   v1.29.6
```

The exact node names may differ depending on the hostnames configured on the worker nodes.

---

## Detailed Node Information

```bash
kubectl get nodes -o wide
```

This displays:

* Node status
* Kubernetes version
* Internal IP
* External IP
* OS
* Kernel
* Container runtime

---

## Check All Kubernetes Pods

```bash
kubectl get pods -A
```

---

## Check Calico

```bash
kubectl get pods -n calico-system
```

---

## Check Cluster Information

```bash
kubectl cluster-info
```

---

## Check kubelet

Run on each node:

```bash
sudo systemctl status kubelet
```

Or:

```bash
sudo systemctl is-active kubelet
```

Expected:

```text
active
```

---

## Check containerd

Run on each node:

```bash
sudo systemctl status containerd
```

Or:

```bash
sudo systemctl is-active containerd
```

Expected:

```text
active
```

---

# 7. Deploy a Test Application

After all nodes are `Ready`, deploy a test NGINX application.

Create the deployment:

```bash
kubectl create deployment nginx --image=nginx
```

Check the deployment:

```bash
kubectl get deployments
```

Check the pods:

```bash
kubectl get pods -o wide
```

Expose the deployment using NodePort:

```bash
kubectl expose deployment nginx \
  --type=NodePort \
  --port=80
```

Check the service:

```bash
kubectl get svc
```

Example:

```text
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
nginx   NodePort   10.x.x.x        <none>        80:30xxx/TCP
```

The NodePort will be allocated from:

```text
30000-32767
```

---

# Networking

This lab contains three separate network concepts.

## AWS VPC Network

```text
172.31.0.0/16
```

## AWS Public Subnet

```text
172.31.1.0/24
```

## Kubernetes Pod Network

```text
192.168.0.0/16
```

The Kubernetes Pod CIDR is configured during control-plane initialization:

```bash
--pod-network-cidr=192.168.0.0/16
```

Calico provides networking between Kubernetes pods.

---

# Security Groups

## Control Plane Security Group

| Protocol |          Port | Source               | Purpose               |
| -------- | ------------: | -------------------- | --------------------- |
| TCP      | `10248-10260` | VPC                  | Kubernetes components |
| TCP      |   `2379-2380` | VPC                  | etcd                  |
| TCP      |        `6443` | VPC                  | Kubernetes API Server |
| TCP      |          `22` | `106.192.162.183/32` | SSH                   |
| All      |           All | `0.0.0.0/0`          | Outbound              |

## Worker Security Group

| Protocol |          Port | Source               | Purpose             |
| -------- | ------------: | -------------------- | ------------------- |
| TCP      |       `10250` | VPC                  | Kubelet             |
| TCP      |       `10256` | VPC                  | kube-proxy          |
| TCP      | `30000-32767` | VPC                  | Kubernetes NodePort |
| TCP      |          `22` | `106.192.162.183/32` | SSH                 |
| All      |           All | `0.0.0.0/0`          | Outbound            |

> SSH access is restricted to the configured administrator IP. If your public IP changes, update the Terraform configuration before attempting SSH access.

---

# IP Address Handling

The control-plane script does not hardcode EC2 addresses.

It retrieves the instance's:

```text
Private IP
Public IP
```

from the AWS EC2 Instance Metadata Service.

The private IP is used for:

```text
Kubernetes API Server advertisement
```

The public IP is added as an API server certificate SAN.

This is important because EC2 public and private IP addresses can change when an instance is destroyed and recreated.

---

# Troubleshooting

## Check kubelet logs

```bash
sudo journalctl -u kubelet -f
```

Check the service:

```bash
sudo systemctl status kubelet
```

---

## Check containerd logs

```bash
sudo journalctl -u containerd -f
```

Check the service:

```bash
sudo systemctl status containerd
```

---

## Check Kubernetes Nodes

```bash
kubectl get nodes -o wide
```

---

## Check Kubernetes System Pods

```bash
kubectl get pods -A
```

---

## Check Calico

```bash
kubectl get pods -n calico-system
```

---

## Generate a New Worker Join Command

On the control plane:

```bash
kubeadm token create --print-join-command
```

---

# Cleanup

This is a temporary Kubernetes laboratory environment.

When the lab is no longer required, destroy the AWS resources.

From the Terraform directory:

```bash
terraform destroy
```

Review the resources Terraform plans to remove and confirm:

```text
yes
```

This removes the Terraform-managed:

* EC2 instances
* Security groups
* Public subnet
* Route table
* Internet Gateway
* VPC

---

# GitHub Security

Do not commit sensitive information to the repository.

Never commit:

```text
AWS credentials
AWS secret keys
SSH private keys
Terraform state files
Environment files containing secrets
Kubernetes tokens
Kubernetes certificates
```

Recommended `.gitignore`:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log

# Terraform variable files
*.tfvars
*.tfvars.json

# SSH keys
*.pem
*.key

# Environment files
.env
.env.*

# AWS credentials
.aws/

# OS files
.DS_Store
Thumbs.db
```

If `terraform.tfvars` contains only non-sensitive lab configuration, it can be committed if desired. For a safer repository, keep it out of Git and provide a `terraform.tfvars.example` file instead.

---

# Learning Flow

The complete lab follows this sequence:

```text
AWS Account
     |
     v
Terraform
     |
     v
VPC
     |
     +----------------------+
     |                      |
     v                      v
Public Subnet        Internet Gateway
     |
     v
Security Groups
     |
     v
EC2 Instances
     |
     +-----------------------+----------------------+
     |                       |                      |
     v                       v                      v
Control Plane             Worker 1               Worker 2
     |                       |                      |
     +-----------------------+----------------------+
                             |
                             v
                  Server Preparation
                             |
                             v
              containerd + kubeadm + kubelet
                             |
                             v
                       kubeadm init
                             |
                             v
                         Calico CNI
                             |
                             v
                    kubeadm join
                             |
                             v
                  Kubernetes 3-Node Cluster
                             |
                             v
                     Deploy Workloads
```

---

# Final Cluster

The expected final cluster consists of:

```text
                    Kubernetes Cluster
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Control Plane                  Workers
             |                           |
        +----+----+                 +----+----+
        |         |                 |         |
        v         v                 v         v
     kubeadm   Calico            Worker 1   Worker 2
     kubelet     CNI
     kubectl
     containerd
```

The final verification should show all three nodes in the `Ready` state:

```bash
kubectl get nodes
```

```text
NAME      STATUS   ROLES           AGE   VERSION
master    Ready    control-plane   ...   v1.29.6
worker1   Ready    <none>          ...   v1.29.6
worker2   Ready    <none>          ...   v1.29.6
```

---

## Purpose

This repository is intended as a Kubernetes learning laboratory covering:

* AWS infrastructure provisioning
* Terraform
* VPC networking
* EC2
* Linux server preparation
* Containerd
* Kubernetes installation
* kubeadm
* kubelet
* kubectl
* Kubernetes networking
* Calico
* Control-plane initialization
* Worker-node joining
* Kubernetes workload deployment
* Basic cluster troubleshooting
* Infrastructure cleanup

This is a learning environment and should not be considered a production-ready Kubernetes architecture.

---

## Version Note

This lab intentionally uses pinned versions for reproducibility.

Kubernetes `1.29.6` is an older Kubernetes release. If this repository is reused for a new lab in the future, verify that the specified Kubernetes, containerd, runc, CNI, and Calico versions remain compatible before changing versions independently.

