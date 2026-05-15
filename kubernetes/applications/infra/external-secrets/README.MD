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
1. Create SOPS age key (i've chosen the post-quantum type)
```bash
age-keygen -o age.key -pq
```

2. Login to Google Cloud with CLI and store generated key file in Google Secret Manager. For regional secret you need to define the `--location` parameter explicit. Make also sure, to temporarily override the API endpoint to the choosen region.
```bash
$ glcoud init

$ gcloud config set api_endpoint_overrides/secretmanager https://secretmanager.<REGION-CODE>.rep.googleapis.com/
Updated property [api_endpoint_overrides/secretmanager].

$ gcloud secrets create secret-name (--location=<REGION-CODE>)
Created secret [secret-name].

$ gcloud secrets versions add secret-name --data-file=age.key
Created version [1] of the secret [secret-name].
```

3. Verify the created secret and its content:
```bash
$ gcloud secrets describe secret-name (--location=<REGION-CODE>)

createTime: '2026-05-13T19:01:00.378672Z'
etag: '"XXXXXXXXXXXXXX"'
name: projects/############/locations/<REGION-CODE>/secrets/secret-name

$ gcloud secrets versions access 1 --secret=secret-name (--location=<REGION_CODE>)
```

4. Create GCP service account, grant read access to secrets and create credential file for external-secrets deployment:
```bash
$ gcloud iam service-accounts create eso-sa --display-name="ESO Service Account"
Created service account [eso-sa].

$ gcloud projects add-iam-policy-binding <YOUR_PROJECT_ID> --member="serviceAccount:eso-sa@<YOUR_PROJECT_ID>.iam.gserviceaccount.com" --role="roles/secretmanager.secretAccessor"

Updated IAM policy for project [<YOUR_PROJECT_ID>].

bindings:
- members:
  - user:john.doe@gmail.com
  role: roles/owner
- members:
  - serviceAccount:eso-sa@b<YOUR_PROJECT_ID>.iam.gserviceaccount.com
  role: roles/secretmanager.secretAccessor
etag: XxxYyyZzz012=
version: 1

$ gcloud iam service-accounts keys create eso-key.json --iam-account eso-sa@<YOUR_PROJECT_ID>.iam.gserviceaccount.com

created key [abcdef1234567890abcdef1234567890abcdef12] of type [json] as [eso-key.json] for [eso-sa@<YOUR_PROJECT_ID>.iam.gserviceaccount.com]
```

5. Inject GSM credentials via Talos
```yaml
cluster:
  inlineManifests:
    - |
      apiVersion: v1
      kind: Secret
      metadata:
        name: gsm-auth
        namespace: infra-flux
      type: Opaque
      stringData:
        credentials.json: |
          {
            ... contents of eso-key.json ...
          }
```


> Step 5-7 — Add External Secrets Operator (Flux) - in applications/infra/external-secrets
  DONE
  
> Step 8 — Add ESO to infra aggregation
  DONE
 
> Step 9 — Enable SOPS in Flux (automatic)
	Flux automatically detects: 
	Secret name: sops-age
	Key: age.agekey
	
> Step 10 — Config to encrypt your sensitive files (.sops.yaml)
  DONE
  
> Step 11 - Encrypt file locally and push to git

> Step 12 — First full deploy sequence (what happens)
