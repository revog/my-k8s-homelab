# Talos

[Talos Linux](https://www.talos.dev/) is a modern OS for Kubernetes. It's designed to be secure, immutable and minimal. I run a three-node Talos Linux Kubernetes cluster in my homelab.

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

### Build Configuration
The Talos configuration is deliberately separated. Separating configuration from secrets increases flexibility, security, and operational simplicity. The reasons for this are:
* Separation enables **safe reconfiguration**: Machine configurations reconfiguration without changing secrets and allowing cluster updates without disrupting existing nodes.
* **Improved security** with version control: Machine configurations can be stored in Git while secrets remain separate, reducing the risk of credential exposure.
* Easier **secret rotation**: Secrets (like certificates or tokens) can be rotated independently by generating a new secrets bundle and rebuilding configs.

#### Generate secrets bundle
The secrets bundle is a file that contains all the cryptographic keys, certificates, and tokens needed to secure your Talos Linux cluster.
```bash
talosctl gen secrets -o talos/generated/secrets.yaml
```
They deserve special care by being kept under lock and key and secret. The secrets are mandatory for cluster lifecycle and future tasks. So please, handle with care and make sure that they are available when communicating with the Talos instances!
Will put the secrets to a safe location - e.g. Password Safe / Secret Vaultf and push a `sops`-encrypted variante to the repository.
```bash
# Encrypt the secrets file with SOPS using age
sops --encrypt --age age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx talos/generated/secrets.yaml > talos/generated/secrets.enc.yaml

# Later, decrypt when you need to generate configs
sops --decrypt talos/generated/secrets.enc.yaml > talos/generated/secrets.yaml

# Clean up the decrypted file
rm talos/generated/secrets.yaml
```

#### Generate machine configurations
Talos uses declarative configuration for clusters, but upgrades can cause drift between the declared machine configuration (files you keep in Git) and the deployed configuration (what’s actually running on the nodes).
To prevent this drift, it is recommend discarding full declared configuration files and instead using a patch-based workflow to regenerate machine configuration whenever you need them.

Follow these steps to generate initial machine configuration. The command will generate three files using the previously created secrets bundle:
* **controlplane.yaml**: Configuration for your control plane node(s)
* **worker.yaml**: Configuration for your worker nodes
* **talosconfig**: The talosctl configuration file used to connect to and authenticate with your cluster
```bash
talosctl gen config --output-dir talos/generated --with-secrets talos/generated/secrets.yaml <CLUSTER_NAME> https://<CLUSTER_API_VIP>:6443
```
The default machine configurations for control plane and worker nodes are typically sufficient to get the cluster running. However, it is more convenient separating certain customization settings such as network interfaces and disk configurations etc. to seperate node-specific files.

Beside of node-specific patches there can be created also general - like cluster-related - patch files.

To regenerate your machine configuration create new configs using inputs from existing files (secrets.yaml, patches) and inputs (cluster-name, endpoint, ...):
```bash
CLUSTER_NAME=<CLUSTER_NAME>
CLUSTER_API_VIP=<CLUSTER_API_VIP>
KUBERNETES_VERSION=<KUBERNETES_VERSION>
NODE=<HOSTNAME>
TALOS_VERSION=<TALOS_VERSION>

talosctl gen config $CLUSTER_NAME $CLUSTER_API_VIP \
  --with-secrets secrets.yaml \
  --kubernetes-version $KUBERNETES_VERSION \
  --talos-version $TALOS_VERSION \
  --config-patch @generated/common.yaml \
  --config-patch-control-plane @patches/patch-controlplane.yaml \
  --config-patch @patches/patch-$NODE.yaml \
  --output rendered/$NODE.yaml

talosctl gen config $CLUSTER_NAME $CLUSTER_API_VIP \
    --with-secrets talos/generated/secrets.yaml \
    --kubernetes-version $KUBERNETES_VERSION \
    --talos-version $TALOS_VERSION \
    --config-patch @generated/common.yaml \
    --config-patch-control-plane @generated/controlplane.yaml \
    --config-patch-control-plane @patches/patch-controlplane.yaml \
    --config-patch-worker @generated/worker.yaml \
    --config-patch @patches/patch-$NODE.yaml \
    --output talos/rendered/$NODE.yaml
```

### Apply Configuration
After pre-rendering the node configuration, they can be easily applied. Initially it is mandatory to bootstrap the cluster. 
Additional nodes can be added the same way. For future configuration changes/updates use the same procedure.

#### Bootstrapping first node
```bash
NODE=<HOSTNAME>
# Apply config to node01 (use --insecure on first apply)
talosctl apply-config --insecure --nodes $(host $NODE) --file talos/rendered/$NODE.yaml

# Set endpoint and reboot
talosctl config endpoint <CLUSTER_VIP>
talosctl config node $(host $NODE)
talosctl reboot --nodes $(host $NODE)

# Bootstrap cluster (only once, only on first control plane node!)
talosctl bootstrap

# Verify health
talosctl health --wait-timeout 10m
```
After accomplished bootstrapping process it is possible to fetch de kubeconfig through `talosctl` and connecting to Kubernetes cluster with `kubectl`:
```bash
# Get kubeconfig
talosctl kubeconfig .
export KUBECONFIG=./kubeconfig

kubectl get nodes
```
#### Update/Add nodes
Once a fully bootstrapped Kubernetes cluster is in place, additional nodes can be joined. 
The following commands (`apply-config` und `reboot`) also apply to applying future configuration changes (simply ommit `--insecure` as hosts are known).

```bash
# Control plane nodes
NODE=<HOSTNAME>
# Apply config to control-plane node02 & node03
talosctl apply-config --insecure --nodes $(host $NODE) --file talos/rendered/$NODE.yaml
talosctl reboot --nodes $(host $NODE)
```
```bash
NODE=<HOSTNAME>
# Apply config to worker node04
talosctl apply-config --insecure --nodes $(host $NODE) --file talos/rendered/$NODE.yaml
talosctl reboot --nodes $(host $NODE)
```

# Omni
Omni is a Kubernetes management platform that simplifies the creation and management of Kubernetes clusters on any environment to provide a simple, secure, and resilient platform. It automates cluster creation, management and upgrades, and integrates Kubernetes and Omni access into enterprise identity providers. While Omni does provide a powerful UI, tight integration with Talos Linux means the platform is 100% API-driven from Linux to Kubernetes to Omni.

I run Omni .....


