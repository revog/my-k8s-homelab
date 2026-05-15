# External Secrets Operator
This component deploys the **External Secrets Operator (ESO)** and configures integration with **Google Secret Manager (GSM)**.
It is responsible for retrieving the decryption key from GSM and exposing them as Kubernetes Secrets inside the cluster.

External Secrets enables:
- centralized secret storage in Google Secret Manager
- dynamic retrieval of secrets into Kubernetes
- decoupling of secrets from Git
- enabling SOPS decryption via AGE key

It depends on accomplished setup of Google Secret Manager.

# Google Secret Manager
Secret Manager is a secure and convenient storage system for API keys, passwords, certificates, and other sensitive data.

## Initial Setup
<tbd>
