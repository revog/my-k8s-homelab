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
Following instructions and steps are based on the [official documentation](https://docs.siderolabs.com/) of Sidero Labs Talos.

My hardware setup is based on some Raspberry Pi 5 nodes extended with Storage respectively AI HATs:
| Node | Role | Storage | Special |
|---|---|---|---|
| node01 | control-plane + worker | Raspberry Pi 5 8GB | Hailo AI HAT |
| node02 | control-plane + worker | Raspberry Pi 5 8GB | M.2 NVMe HAT |
| node03 | control-plane + worker | Raspberry Pi 5 16GB | M.2 NVMe HAT |
| node04 | worker | (not yet in use) |  |

**SD cards:** 64GB SanDisk High Endurance microSDHC (Class 10 / A1)  
**NVMe:** M.2 2280 NVMe (PCIe Gen 3/4) for Longhorn SDS

Due to the limited node count, I will use the control-plane nodes for workload scheduling aswell.

### Prerequisites
Make sure to install the Talos Linux CLI on the workstation prior starting with the deployment. The client can be installed and updated from several sources like package manager (recommended), online [installer script](https://talos.dev/install) or [releases page](https://github.com/siderolabs/talos/releases). 
```
brew install siderolabs/tap/talosctl
```
Every node node needs a unique IP address plus a moving VIP (Virtual IP) for Kubernetes API. Talos does automatically failover the VIP to a designated node and ensuring the Kubernetes API availability all the time. 

### Image build and deployment
As the hardware setup derives from an "out-of-the-box-setup", I will use a customized image build. Thanks to the official [Sidero Labs Image Factory](https://factory.talos.dev/) it is quite easy building a customized image based on your needs.
The factory validates the schematic and calculates a deterministic hash from which it is possible building images. It does not permanently store images but its recipe.

#### Generate schematic (aka image recipe)
##### Variant 1: Online Form
The online form will guide through the process and will provide a unique schemantic ID for downloading the specific image.

- Hardware Type: Single Board Computer (SBC)
- Talos Linux Version: 1.13.0
- Single Board Computer: Raspberry Pi 5
- System Extensions:
  - siderolabs/iscsi-tools (required for Longhorn)
  - siderolabs/util-linux-tools (required for Longhorn)
  - siderolabs/hailort (required for Hailo NPU)

##### Variant 2: Local prep
Alternatively it is possible to achieve the same with an manual/scriptable approach by creating a local YAML manifest, submitting it with `curl` and downloading it afterwards with the returned schematic id.

**`rpi5-schematic.yaml`**
```yaml
overlay:
  name: rpi_5
  image: siderolabs/sbc-raspberrypi
customization:
  systemExtensions
    officialExtensions:
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
      - siderolabs/hailort
```

Submit schematic to get schematic id:
```bash
curl -s -X POST --data-binary @rpi5-schematic.yaml https://factory.talos.dev/schematics -H "Content-Type: application/x-yaml"
```

#### Download image
Use the returned schematic ID for downloading customized image and extract:
```bash
SCHEMATIC="<schematic-id>"
VERSION="v1.13.0"

curl -L "https://factory.talos.dev/image/${SCHEMATIC}/${VERSION}/metal-arm64.raw.xz" -o metal-arm64.raw.xz
xz -d metal-arm64.raw.xz
```

#### Install image on SD card
Installation to SD card's can easily be done with local tools like `diskutil` and `dd`:
```bash
# Identify SD card
diskutil list

# Unmount
diskutil unmountDisk /dev/diskX

# Flash (using rdisk as it is faster on macOS)
sudo dd if=metal-arm64.raw of=/dev/rdiskX bs=4m status=progress

# Eject
diskutil eject /dev/diskX
```
Finally insert the SD card into the Raspberry Pi and boot up. It starts Talos Linux in **Maintenance Mode** and should be reachable through a DHCP IP.

### Generate Cluster configuration

### Image deployment

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

