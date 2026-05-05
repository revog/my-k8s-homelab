# Talos

Talos Linux is a modern OS for Kubernetes. It's designed to be secure, immutable and minimal. I run a three-node Talos Linux Kubernetes cluster in my homelab.

It runs on your Kubernetes nodes and hosts your workloads. It also runs the Kubernetes control plane components including the etcd database. With a single use case and focus it removes complicated and fragile configuration, maintenance, and security vulnerabilities.
It’s designed to be as minimal as possible while still maintaining practicality. For these reasons, Talos has a number of features unique to it:
* API managed
* Immutable file system
* Minimal packages
* Secure by default

Talos is managed by a single, declarative gRPC API - no ssh, no bash. This is the most unique thing about Talos and something Talos users love.

## Setup <tbd>

Step 1: Decide the Kubernetes API Endpoint
Step 2: Generate Cluster Configuration
Step 3: Configure (Control Plane) Nodes
Step 4: Configure Other Nodes
...

## Configuration

As for the cluster I don't do a whole lot of configuration, Omni takes care of alot but since I just run 3 nodes I allow scheduling on the control plane. Other than that I just change the machine host name.

```yaml
cluster:
  allowSchedulingOnControlPlanes: true
```

```yaml
machine:
  network:
    hostname: "talos-1"
```

I also install the qemu-guest-agent and iscsi system extensions, but that was a one time choice when setting up the cluster with Omni, then it makes sure to include it in subsequent images. The "old" folder contains some docs on how to do it manually with the image factory.

# Omni
Omni is a Kubernetes management platform that simplifies the creation and management of Kubernetes clusters on any environment to provide a simple, secure, and resilient platform. It automates cluster creation, management and upgrades, and integrates Kubernetes and Omni access into enterprise identity providers. While Omni does provide a powerful UI, tight integration with Talos Linux means the platform is 100% API-driven from Linux to Kubernetes to Omni.

I run Omni .....

