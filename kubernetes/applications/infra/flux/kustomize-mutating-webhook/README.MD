# FluxCD Kustomize Mutating Webhook
This [project](https://github.com/xunholy/fluxcd-kustomize-mutating-webhook) introduces a mutating webhook for FluxCD Kustomization, designed to extend the functionality of postBuild substitutions beyond the scope of a single namespace. It allows for the use of global configuration variables stored in a central namespace, thus avoiding the need for recursive Kustomize patches or duplicated secrets across multiple namespaces.

## Why This Webhook?
In standard FluxCD setups, postBuild substitutions in Kustomizations can only reference secrets within the same namespace. This limitation can lead to redundancy and complexity, particularly in environments requiring consistent configuration across multiple namespaces. This mutating webhook addresses this challenge by enabling global configuration management, significantly simplifying the process.

## How It Works
The webhook listens for Kustomization resources creation or update events. On intercepting such an event, it dynamically injects substitution variables into the Kustomization resource. These variables are fetched from centralized ConfigMaps or Secrets, allowing for consistent and centralized management of configurations used across various namespaces.

Detailed information can be found on the project's repository at https://github.com/xunholy/fluxcd-kustomize-mutating-webhook.