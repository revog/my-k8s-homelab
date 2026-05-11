<div align="center">
  
# My K8s Homelab
🚀 Home Operations Repository 🚧 _... managed with ArgoCD, Renovate, GitHub Actions 🤖 and others._

</div>

<div align="center">
  
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue)](https://kubernetes.io/)&nbsp;&nbsp;
[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=blue)](https://talos.dev)&nbsp;&nbsp;
[![ArgoCD](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fargocd_version&style=for-the-badge&logo=argocd&logoColor=white&color=blue)](https://argoproj.github.io/)&nbsp;&nbsp;

</div>

<div align="center">
  
[![Age-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fcluster_age_days&style=flat-square&label=Age)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Uptime-Days](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fcluster_uptime_days&style=flat-square&label=Uptime)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fsubdomain.TO-BE-DEFINED.tld%2Fcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo)&nbsp;&nbsp;

</div>

# 📖 Overview
This repository serves as both the source of truth (Iac) for my GitOps-driven Kubernetes deployments and a personal knowledge base documenting my homelab journey. I’ve made it public in the hope that others can learn from it, reuse parts of it, or simply explore how a real-world, production-grade homelab is structured.

This project's main goal is to provide a hands-on learning experience for designing, deploying, and operating Kubernetes clusters using modern best practices. It focuses on:
* Declarative cluster management using **GitOps principles**
* Implementing **Enterprise-grade security patterns** adapted for homelab use
* **Observability and monitoring** across the entire stack
* Scalable and reproducible **configuration management**
* Practical, **real-world** Kubernetes **operations**
* ... and always fostering learning and growth in the Kubernetes community.

This repository leverages a range of cutting-edge open-source tools and platforms, forming a comprehensive technology stack that demonstrates the power of the whole [CNCF ecosystem](https://landscape.cncf.io/).

## 📖 Table of contents
- 🍼 [Overview](#-overview)
  - 📖 [Table of contents](#-table-of-contents)
  - 🔧[Hardware](#-hardware)
  - ☁️ [Cloud Services](#️-cloud-services)
  - 🖥️ [Technology Stack](#️-technology-stack)
    - 🚀 [Kubernetes](#-kubernetes)
      - 😶 [Core Components](#-core-components)
      - ⚙ [GitOps](#-gitops)
    - 🌎 [Networking & DNS](#-networking-dns)
      - 🔒 [Local Network](#-local-network)
      - 💻 [Remote Network (Exposed)](#-remote-network-exposed)
        - 🪬 [Privately Exposed (Tailscale)](#-privately-exposed-tailscale)
        - 🔓 [Publicly Exposed (Cloudflare)](#-publicly-exposed-cloudflare)
    - 📁 [Directory Structure](#-directory-structure)
  - 🤝 [Acknowledgements](#-acknowledgements)
  - 👥 [Contributing](#-contributing)
    - 🚫 [Code of Conduct](#-code-of-conduct)
    - 💡 [Reporting Issues and Requesting Features](#-reporting-issues-and-requesting-features)
  - 📄 [License](#-license)

## 🔧 Hardware
| Device | Description | Quantity | CPU | RAM | Storage | Architecture | Operating System |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Provider's Internet Router | Router/Gateway | 1 | - | - | - | - | - |
| Network Gear | Network Switch | 1 | - | - | - | - | - |
| [Raspberry Pi 5](https://www.raspberrypi.com/products/raspberry-pi-5/) | K8s Nodes | 3 | 12 cores | 32GB | 3 x  512GB NVMe | AMD64 | [Talos Linux](https://www.talos.dev/) |
| NAS | Storage | 1 | 8 cores | 16GB | 48TB | arm64 | [QNAP](https://www.qnap.com/) |

## ☁️ Cloud Services
I always try (whenever possible) to build and manage my infrastructure and workloads on-prem and on my own. But there are specific components of my setup that rely on cloud services. This saves me from having to worry about: 
(1) Dealing with chicken/egg scenarios
(2) services I critically need whether my cluster is online or not

| Service                                   | Description                                                                                                 | Cost     |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------- | -------- |
| [Cloudflare](https://www.cloudflare.com/) | I use Cloudflare in my home network for DNS management and to secure my domain with Cloudflare's services.  | ~$?/yr   |
| [GitHub](https://github.com/)             | Using GitHub for hosting this repository - code management and version control                              | Free     |
| [Lets Encrypt](https://letsencrypt.org/)  | Using Let's Encrypt to generate certificates for secure communication to and within my network.             | Free     |
| [Tailscale](https://tailscale.com/)       | Using Tailscale access privately (non-public) exposed services from the internet                            | Free     |

## 🖥️ Technology Stack
The below showcases the collection of open-source solutions currently implemented in the cluster. Each of these components has been carefully documented, and their deployment is managed using ArgoCD, which adheres to GitOps principles.

### 🚀 Kubernetes
My Kubernetes cluster is deployed with [Talos](https://www.talos.dev/), running on multiple Raspberry Pi's. This is a mini-semi-hyper-converged cluster, workloads and block storage are sharing the same available resources on my nodes while I have a separate NAS with disk space for NFS/SMB shares, bulk file storage and backups.
#### 😶 Core Components
* Networking & Service Mesh: **cilium** provides eBPF-based networking, while istio powers service-to-service communication with L7 proxying and traffic management. cloudflared secures ingress traffic via Cloudflare, and external-dns keeps DNS records in sync automatically.
* Security & Secrets: **cert-manager** automates SSL/TLS certificate management. For secrets, I use external-secrets with 1Password Connect to inject secrets into Kubernetes.
* Storage & Data Protection: **longhorn** provides distributed storage for persistent volumes, with **velero/kasten (tbd?)** handling backups and restores. **spegel** improves reliability by running a stateless, cluster-local OCI image mirror.
* Automation & CI/CD: **actions-runner-controller** runs self-hosted GitHub Actions runners directly in the cluster for continuous integration workflows.

#### ⚙ GitOps
[ArgoCD](https://argo-cd.readthedocs.io/) follows a GitOps model where applications are deployed by reconciling explicitly defined Application resources against Git. Each Application points to a specific repository path and uses either Helm, Kustomize, or raw manifests to render Kubernetes resources. ArgoCD continuously monitors Git for changes and synchronizes the cluster to match the desired state (YAMLs & HelmRelase) in my [kubernetes](/kubernetes) folder and its subfolders (see structure below). Dependencies between applications are handled through sync waves, health checks, or the app‑of‑apps pattern, rather than explicit dependency declarations.

This repository is automatically managed by [Renovate](https://renovatebot.com/). Renovate watches my entire repository looking for dependency updates, when they are found a PR is automatically created. When some PRs are merged ArgoCD applies the changes to my cluster.

The Cloud Native Computing Foundation (CNCF) has played a crucial role in the development and popularization of many of these tools, driving the adoption of cloud-native technologies and enabling projects like this one to thrive.
| |                                                                                                                                       | Name                                                            | Description                                                                                               |
|-| ------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
|✅| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/kubernetes/icon/color/kubernetes-icon-color.svg">             | [Kubernetes](https://kubernetes.io/)                            | An open-source system for automating deployment, scaling, and management of containerized applications    |
|✅| <img width="32" src="https://www.talos.dev/favicon.svg">                                                                             | [Talos Linux](https://www.talos.dev/)                           | Minimal, immutable Linux OS designed for Kubernetes                                                       |
|✅| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/containerd/icon/color/containerd-icon-color.svg">             | [containerd](https://containerd.io/)                            | Industry-standard container runtime integrated with Talos Linux                                           |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/coredns/icon/color/coredns-icon-color.svg">                   | [CoreDNS](https://coredns.io/)                                  | Flexible, plugin-based DNS server for Kubernetes service discovery                                        |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/cilium/icon/color/cilium_icon-color.svg">                     | [Cilium](https://cilium.io/)                                    | eBPF-based CNI providing networking, security, and observability                                          |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/envoy/icon/color/envoy-icon-color.svg">                       | [Envoy Gateway](https://gateway.envoyproxy.io/)                 | Kubernetes Gateway API implementation built on Envoy proxy                                                |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/argo/icon/color/argo-icon-color.svg">                         | [ArgoCD](https://argo-cd.readthedocs.io/)                       | GitOps continuous delivery for Kubernetes                                                                 |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/helm/icon/color/helm-icon-color.svg">                         | [Helm](https://helm.sh)                                         | The Kubernetes package manager                                                                            |
|⚠️| <img width="32" src="https://avatars.githubusercontent.com/u/36015203">                                                              | [Node Feature Discovery](https://kubernetes-sigs.github.io/node-feature-discovery) |  Add-on for detecting hardware features and system configuration for dynamic scheduling|
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/metallb/icon/color/metallb-icon-color.svg">                   | [MetalLB](https://metallb.io/)                                  | Load balancer for bare metal Kubernetes clusters                                                          |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/cert-manager/icon/color/cert-manager-icon-color.svg">         | [cert-manager](https://cert-manager.io/)                        | X.509 certificate management for Kubernetes                                                               |
|⚠️| <img width="32" src="https://raw.githubusercontent.com/external-secrets/external-secrets/main/assets/eso-logo-large.png">            | [External Secrets](https://external-secrets.io/)                | Synchronize secrets from external APIs (1Password) into Kubernetes                                        |
|⚠️| <img width="32" src="https://raw.githubusercontent.com/kubernetes-sigs/external-dns/master/docs/img/external-dns.png">               | [ExternalDNS](https://github.com/kubernetes-sigs/external-dns)  | Automatically manage DNS records from Kubernetes resources                                                |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/longhorn/icon/color/longhorn-icon-color.svg">                 | [Longhorn](https://longhorn.io/)                                | Cloud-native, lightweight, reliable and easy-to-use distributed block storage system for Kubernetes       |
|⚠️| <img width="32" src="https://raw.githubusercontent.com/backube/volsync/main/docs/media/volsync.svg">                                 | [Volsync](https://volsync.readthedocs.io/)                      | Asynchronous data replication for Kubernetes persistent volumes                                           |
|⚠️| <img width="32" src="https://avatars.githubusercontent.com/u/99631794">                                                              | [Spegel](https://github.com/spegel-org/spegel)                  | Stateless cluster-local OCI registry mirror                                                               |
|⚠️| <img width="32" src="https://github.com/cncf/artwork/raw/main/projects/prometheus/icon/color/prometheus-icon-color.svg">             | [Prometheus](https://prometheus.io)                             | Monitoring system and time series database                                                                |
|⚠️| <img width="32" src="https://grafana.com/static/img/menu/grafana2.svg">                                                              | [Grafana](https://grafana.com)                                  | Analytics and monitoring dashboards                                                                       |
|⚠️| <img width="32" src="https://raw.githubusercontent.com/oauth2-proxy/oauth2-proxy/master/docs/static/img/logos/OAuth2_Proxy_icon.svg">| [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/)    | Reverse proxy providing authentication with external OAuth2 providers                                     |
|⚠️| <img width="32" src="https://avatars.githubusercontent.com/u/314135">                                                                | [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) | Secure outbound-only tunnel for exposing services without public IPs  |

### 🌎 Networking & DNS
Apps hosted on my cluster are exposed using any combination of three different methods, depending on their use-case, security requirements, and intended audience. All three methods utilise fully encrypted HTTPS connections – TLS certificates are automatically provisioned and renewed by [Cert Manager](https://cert-manager.io/) for each application.
This setup is managed by creating ingresses with specific classes: `internal` for local services, `private` for privately exposed services and `public` for public DNS. The external-dns instances then syncs the DNS records to their respective platforms accordingly.

#### 🔒 Local Network
The first and easiest way that an app can be exposed is strictly on my local network. This is most often used for apps and services that have to do with home automation or simply used in my local network, there is no need to expose those any further than that.
Local deployments are accomplished by creating an Ingress of type `internal`, which will register a virtual IP for the service in a designated subnet and provision a DNS record in local DNS.

#### 💻 Remote Network (Exposed)
The remote service type differs between privately but "on the road" used and publicly exposed services.

##### 🪬 Privately Exposed (Tailscale)
The second and most common way that an app can be exposed is via [Tailscale](https://tailscale.com/docs/features/kubernetes-operator). Creating an Ingress with the `private` class will expose the application to my Tailnet, and [automagically](https://tailscale.com/docs/features/magicdns) configure DNS records. Most self-hosted apps and dashboards are exposed using this Ingress class, so that they are accessible on my personal devices at a consistent URL no matter if I'm at home or abroad.
Tailscale also serves as a Kubernetes auth proxy, which I use in conjunction with the Nautik iOS app to monitor and administer my Kubernetes cluster on-the-go.

##### 🔓 Publicly Exposed (Cloudflare)
The final and least common way to expose an app is via cloudflared - the [Cloudflare Tunnel](https://developers.cloudflare.com/learning-paths/replace-vpn/connect-private-network/cloudflared/) daemon. Creating an Ingress with the `public` class will route all external traffic through Cloudflare's infrastructure, I gain the benefits of their global security infrastructure (notably DDoS protection). This is generally used for webhook endpoints which require access from the wider Internet, though I do expose a select few apps for friends and family.

Creating an external Ingress will trigger using ExternalDNS to provision a CNAME DNS record on Cloudflare which points at the Cloudflare Tunnel endpoint. The tunnel routes traffic securely into my cluster, where the ingress controller further routes it to the destination service.

### 📁 Directory Structure
This Git repository contains the following directories and structure:
```sh
📁 talos
├── 📁 generated       # talos base configuration
├── 📁 patches         # customized overrides
📁 kubernetes
├── 📁 applications    # kubernetes deployments
|   ├── 📁 app         # end-user/workload apps
|   └── 📁 infra       # cluster/platform infrastructure components
└── 📁 bootstrap       # bootstrap configuration
```

All Kubernetes manifests are placed under [kubernetes/applications](https://github.com/revog/my-k8s-homelab/tree/main/kubernetes/applications)/*/ and each application lives in its own directory named (without prefix) after the namespace it will be deployed to.
Each application directory typically contains:
* A `kustomization.yaml` that serves as the base entry point refering to HelmChart and/or YAML files.
* A `namespace.yaml` defining the namespace for the app.
* An `app/` subdirectory containing the (optional) custom Kubernetes manifests.

The ArgoCD Kustomization then deploys the application itself using either HelmReleases or plain Kustomize/YAML manifests depending on the app.

ArgoCD is initially bootstrapped through [kubernetes/bootstrap](https://github.com/revog/my-k8s-homelab/tree/main/kubernetes/bootstrap), and from there it automatically fetches the needed information and references from the corresponding app folder within the [applications](https://github.com/revog/my-k8s-homelab/tree/main/kubernetes/applications) directory.

## 🤝 Acknowledgements
A special thank you to everyone out there participating in the OpenSource space. Much of the inspiration for my setup comes from fellow enthusiasts who have shared their own clusters and configurations on the web.

Thanks to all CNCF contributors for their dedication and expertise, as their collective efforts have been vital in driving innovation and success within the cloud-native ecosystem.

## 👥 Contributing
Our project welcomes contributions from any member of our community. To get started contributing, please see our [Contributor Guide](.github/CONTRIBUTING.md).

### 🚫 Code of Conduct
By participating in this project, you are expected to uphold the project's [Code of Conduct](.github/CODE_OF_CONDUCT.md). Please report any unacceptable behavior to the repository maintainer.

### 💡 Reporting Issues and Requesting Features
If you encounter any issues or would like to request new features, please create an issue on the repository's issue tracker. When reporting issues, include as much information as possible, such as error messages, logs, and steps to reproduce the issue.

Thank you for your interest in contributing to this project! Your contributions help make it better for everyone.

## 📄 License
This repository is [Apache 2.0 licensed](./LICENSE)
