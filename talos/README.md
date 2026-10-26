# Talos

[Talos Linux](https://www.talos.dev/) is a modern OS for Kubernetes. It's designed to be secure, immutable and minimal. I run a three-node Talos Linux Kubernetes cluster in my homelab.

It runs on your Kubernetes nodes and hosts your workloads. It also runs the Kubernetes control plane components including the etcd database. With a single use case and focus it removes complicated and fragile configuration, maintenance, and security vulnerabilities.
It’s designed to be as minimal as possible while still maintaining practicality. For these reasons, Talos has a number of features unique to it:
* API managed
* Immutable file system
* Minimal packages
* Secure by default

Talos is managed by a single, declarative gRPC API - no ssh, no bash. This is the most unique thing about Talos and something Talos users love.

My hardware setup is based on handy desktop computer nodes extended with Storage and built-in GPUs:
| Node | Role | Model |
|---|---|---|
| node01 | control-plane + worker | [Beelink EQi Wildcat Lake Core 3 304](https://www.bee-link.com/de/products/beelink-eqi-wildcat-lake) |
| node02 | control-plane + worker | [Beelink EQi Wildcat Lake Core 3 304](https://www.bee-link.com/de/products/beelink-eqi-wildcat-lake) |
| node03 | control-plane + worker | [Beelink EQi Wildcat Lake Core 3 304](https://www.bee-link.com/de/products/beelink-eqi-wildcat-lake) |

**NVMe:** M.2 2280 NVMe (PCIe Gen 3/4) for Longhorn SDS

Due to the limited node count, I will use the control-plane nodes for workload scheduling aswell.


## Setup
Following instructions and steps are based on the [official documentation](https://docs.siderolabs.com/) of Sidero Labs Talos.

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

- Hardware Type: Bare-metal Machine
- Talos Linux Version: v1.14.0 <!-- renovate: datasource=github-releases depName=siderolabs/talos -->
- Machine Architecture: amd64
- System Extensions:
  - siderolabs/iscsi-tools (required for Longhorn)
  - siderolabs/tailscale (required for Tailscale on Node level)
  - siderolabs/util-linux-tools (required for Longhorn)
  - siderolabs/xe (required for Intel GPU)

##### Variant 2: Local prep
Alternatively it is possible to achieve the same with a manual/scriptable approach by creating a local YAML manifest, submitting it with `curl` and downloading it afterwards with the returned schematic id.

**`schematic.yaml.j2`**
```yaml
customization:
  extraKernelArgs:
      - sysctl.kernel.kexec_load_disabled=1   # Security hardening avoids loading new kernel module during runtime
  systemExtensions:
    officialExtensions:
      - siderolabs/iscsi-tools                # iSCSI-based storage support (for Longhorn)
      - siderolabs/tailscale                  # Tailscale
      - siderolabs/util-linux-tools           # Linux utilities
      - siderolabs/xe                         # Intel Xe3 GPU
```

Submit schematic to get schematic id:
```bash
curl -s -X POST --data-binary @schematic.yaml.j2 https://factory.talos.dev/schematics -H "Content-Type: application/x-yaml"
```

#### Download image
Use the returned schematic ID for downloading customized image and extract:
```bash
SCHEMATIC="<schematic-id>"
# renovate: datasource=github-releases depName=siderolabs/talos
VERSION="v1.14.1"
```
```bash
curl -L "https://factory.talos.dev/image/${SCHEMATIC}/${VERSION}/metal-amd64.raw.xz" -o metal-amd64.raw.xz -d metal-amd64.raw.xz
```

#### Install image on USB Stick
Installation to USB stick s can easily be done with local tools like `diskutil` and `dd`:
```bash
# Identify SD card
diskutil list

# Unmount
diskutil unmountDisk /dev/diskX

# Flash (using rdisk as it is faster on macOS)
sudo dd if=metal-amd64.raw of=/dev/rdiskX bs=4m status=progress

# Eject
diskutil eject /dev/diskX
```
Finally plug in the USB stick into the computer and boot up. It starts Talos Linux in **Maintenance Mode** and should be reachable through a DHCP IP.

### Build Configuration
The Talos configuration is deliberately separated. Separating configuration from secrets increases flexibility, security, and operational simplicity. The reasons for this are:
* Separation enables **safe reconfiguration**: Machine configurations reconfiguration without changing secrets and allowing cluster updates without disrupting existing nodes.
* **Improved security** with version control: Machine configurations can be stored in Git while secrets remain separate, reducing the risk of credential exposure.
* Easier **secret rotation**: Secrets (like certificates or tokens) can be rotated independently by generating a new secrets bundle and rebuilding configs.

#### Generate secrets bundle
The secrets bundle is a file that contains all the cryptographic keys, certificates, and tokens needed to secure your Talos Linux cluster.
```bash
talosctl gen secrets -o talos/secrets.yaml
```
They deserve special care by being kept under lock and key and secret. The secrets are mandatory for cluster lifecycle and future tasks. So please, handle with care and make sure that they are available when communicating with the Talos instances!
Will put the secrets to a safe location - e.g. Password Safe / Secret Vaultf and push a `sops`-encrypted variante to the repository.
```bash
# Encrypt the secrets file with SOPS using age
sops --encrypt --age age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx talos/secrets.yaml > talos/secrets.enc.age.yaml

# Later, decrypt when you need to generate configs
sops --decrypt talos/secrets.enc.age.yaml > talos/secrets.yaml

# Clean up the decrypted file
rm talos/secrets.yaml
```

#### Generate machine configurations
Talos uses declarative configuration for clusters, but upgrades can cause drift between the declared machine configuration (files you keep in Git) and the deployed configuration (what’s actually running on the nodes).
To prevent this drift, it is recommend discarding full declared configuration files and instead using a patch-based workflow to regenerate machine configuration whenever you need them.

Follow these steps to generate initial machine configuration. The command will generate three files using the previously created secrets bundle:
* **machineconfig.yaml.j2**: Configuration for your nodes
* **secrets.yaml**: Secrets for cluster and nodes
* **talosconfig**: The talosctl configuration file used to connect to and authenticate with your cluster
```bash
talosctl gen config --output-dir talos --with-secrets talos/secrets.yaml <CLUSTER_NAME> https://<CLUSTER_API_VIP>:6443
```
The default machine configurations for control plane and worker nodes are typically sufficient to get the cluster running. However, it is more convenient separating certain customization settings such as network interfaces and disk configurations etc. to seperate node-specific files.

Beside of node-specific patches there can be created also general - like cluster-related - patch files.

To generate your machine configuration create new configs using inputs from existing files (secrets.yaml, patches) and inputs (cluster-name, endpoint, ...):
```bash
CLUSTER_NAME=<CLUSTER_NAME>
CLUSTER_API_VIP=<CLUSTER_API_VIP>
# renovate: datasource=docker depName=ghcr.io/siderolabs/kubelet
KUBERNETES_VERSION=1.37.1
NODE=<HOSTNAME>
# renovate: datasource=github-releases depName=siderolabs/talos
TALOS_VERSION=v1.14.0

cd talos

talosctl gen config $CLUSTER_NAME $CLUSTER_API_VIP \
  --with-secrets secrets.yaml \
  --kubernetes-version $KUBERNETES_VERSION \
  --talos-version $TALOS_VERSION \
  --config-patch @generated/common.yaml \
  --config-patch-control-plane @patches/patch-controlplane.yaml \
  --config-patch @patches/patch-$NODE.yaml \
  --output rendered/$NODE.yaml
  --output-types controlplane
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
#### Update/Modify or Add nodes
Once a fully bootstrapped Kubernetes cluster is in place, existing configs can be easily modfied or additional nodes can be joined.
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
### Rendering Configuration
#### Prerequisites

Before running the workflow, make sure your terminal has access to your SOPS decryption key (the Age private key):
```bash
export SOPS_AGE_KEY_FILE=<PATH-TO-AGE-KEY>
```
SOPS will read your Age private key, decrypt the sensitive data (like the Tailscale auth keys, token definitions, and Google Service Accounts), and output them into a temporary plain-text patch file.
```bash
sops -d talos/secrets.enc.age.yaml > talos/decrypted_secrets.yaml
```

#### Rendering
This loop automatically processes your nodes. It uses talosctl config patch to dynamically marry the base `machineconfig.yaml.j2` with the newly decrypted secrets. Afterward, it cleanly appends the specific variables from Jinja2 node templates (node01.yaml.j2, etc.).

```bash
for template_file in talos/nodes/*.yaml.j2; do
    node=$(basename "$template_file" .yaml.j2)

    echo "Rendering final configuration for ${node}..."

    talosctl machineconfig patch talos/machineconfig.yam.j2 \
      -p @talos/decrypted_secrets.yaml \
      -p @talos/nodes/${node}.yaml.j2 \
      -o talos/rendered/${node}.yaml

    echo "✓ Created: talos/rendered/${node}.yaml"
done

rm talos/decrypted_secrets.yaml
```

To follow best security practices, erase the plain-text temporary secrets file from local hard drive immediately so that no raw cryptographic material is left exposed.

#### Apply rendered files
Now apply the finalized files (node01.yaml, node02.ready.yaml, and node03.ready.yaml).

If the cluster is active and you are pushing a runtime update (like activating the Tailscale configurations or adding parameters etc.), send the file via talosctl apply-config to the node's target IP:

```bash
talosctl apply-config -n <NODE-IP> --file rendered/<NODE-NAME>.yaml
```

In case of adding an additional host, simply create the rendered config as described and apply with ` --insecure ` to new node's current DHCP IP.


# Omni
Omni is a Kubernetes management platform that simplifies the creation and management of Kubernetes clusters on any environment to provide a simple, secure, and resilient platform. It automates cluster creation, management and upgrades, and integrates Kubernetes and Omni access into enterprise identity providers. While Omni does provide a powerful UI, tight integration with Talos Linux means the platform is 100% API-driven from Linux to Kubernetes to Omni.

I run Omni outside of my Kubernetes cluster on my Storage Appliance as Docker container to avoid chicken-egg-problem during bootstrapping.

## Deployment Architecture & Edge Cases
To successfully run Omni outside the cluster on a storage appliance (e.g., QNAP) while routing traffic through a Kubernetes Ingress/Gateway, two critical network design choices were implemented:

### 1. The SideroLink UDP Bypass (WireGuard)
While UI and API traffic flow through the Kubernetes cluster, Talos nodes require a persistent WireGuard tunnel (`SideroLink`) to Omni. To ensure nodes can always reach the control plane - even if the Kubernetes network is temporarily down or restarting during an upgrade - **the WireGuard traffic completely bypasses Kubernetes**.

* **API/UI Traffic:** `Talos Node` ──(HTTP/2 via Port 443)──> `Cilium Gateway` ──> `Storage Appliance (Omni Container)`
* **SideroLink Traffic:** `Talos Node` ──(Direct UDP via Port 51820)──> `Storage Appliance (Omni Container)`

This is achieved by explicitly advertising the storage appliance's static IP to the nodes using the `SIDEROLINK_WIREGUARD_ADVERTISED_ADDR` environment variable in the Docker container.

### 2. Cilium Gateway API & HTTP/2 Cleartext (h2c)
Omni relies heavily on **gRPC** for node communication. When terminating TLS at the cluster edge via **Cilium Gateway API** and **cert-manager**, Cilium must be explicitly instructed to maintain an HTTP/2 connection to the backend, rather than downgrading it to HTTP/1.1.

* **External Endpoints:** The Storage Appliance is mapped inside Kubernetes using a headless `Service` and manual `Endpoints` targeting the appliance's static IP.
* **Protocol Enforcement:** The Service uses `appProtocol: kubernetes.io/h2c` (HTTP/2 Cleartext). This tells Cilium's Envoy proxy to forward gRPC/HTTP/2 traffic cleanly to Omni's unencrypted port (`8080`).

---

## Configuration Reference

### Kubernetes Backend (`omni-backend.yaml`)
Code of needed YAML manifest is placed under [kubernetes/applications/infra/omni](https://github.com/revog/my-k8s-homelab/tree/main/kubernetes/applications/infra/omni) and will be deployed and managed by Flux.

### Docker Compose (`docker-compose.yaml` on Storage Appliance)
```yaml
version: '3.8'
services:
  omni:
    container_name: omni
    image: ghcr.io/siderolabs/omni:v1.12.4
    restart: unless-stopped
    cap_add:
      - NET_ADMIN # allows creation of WireGuard interfaces
    devices:
      - /dev/net/tun:/dev/net/tun
    command:
      - --account-id=homelab
      - --auth-auth0-enabled=false
      - --auth-oidc-enabled=true
      - --auth-oidc-provider-url=https://auth.${CLUSTER_DOMAIN}
      - --auth-oidc-client-id=${OIDC_CLIENT_ID}
      - --auth-oidc-client-secret=${OIDC_CLIENT_SECRET}
      - --auth-oidc-scopes=openid
      - --auth-oidc-scopes=profile
      - --auth-oidc-scopes=email
      - --bind-addr=0.0.0.0:8080
      - --k8s-proxy-bind-addr=0.0.0.0:8100
      - --initial-users=${PRIVATE_EMAIL}
      - --private-key-source=file:///etc/omni/omni.asc
      - --sqlite-storage-path=/var/lib/omni/omni.db
      - --advertised-api-url=https://omni.internal.${CLUSTER_DOMAIN}
      - --advertised-kubernetes-proxy-url=https://omni.internal.${CLUSTER_DOMAIN}:8100
      - --siderolink-api-advertised-url=https://omni.internal.${CLUSTER_DOMAIN}:8090
      - --siderolink-wireguard-advertised-addr=${STORAGE_IP}:51820
    environment:
      - OMNI_SIDEROLINK_API_CERT_REQUIRED=false
    ports:
      - "8888:8080"       # Omni Web UI (HTTPS)
      - "8090:8090"       # SideroLink gRPC API
      - "8091:8091"       # SideroLink Event Sink
      - "8100:8100"       # Kubernetes Proxy
      - "51820:51820/udp" # WireGuard KubeSpan
    volumes:
      - /share/Container/omni/data:/var/lib/omni
      - /share/Container/omni/omni.asc:/etc/omni/omni.asc:ro
```
