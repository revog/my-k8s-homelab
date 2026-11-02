#!/usr/bin/env bash
# Stage kubernetes/ for an offline flate render: flate-stage.sh <kubernetes dir> <dest dir>
#
# Flux pulls this tree as an OCI artifact (oci.yaml pushes ./kubernetes, so it is the artifact
# root) and each app from an ExternalArtifact that the ArtifactGenerator cuts out of it at
# runtime. flate can resolve neither: it treats the git root as the artifact root and only
# reads ExternalArtifacts from a local status.artifact.url. Rendering from a copy of
# kubernetes/ makes the copy the root, and the apps' paths are the same inside their artifacts,
# so pointing them at the root source renders exactly what the cluster gets.
set -euo pipefail
echo "<< CHECKPOINT 1 >>"
src=$(cd "$1" && pwd)
dest=$2

rm -rf "$dest"
mkdir -p "$dest"
cp -R "$src"/. "$dest"/
cd "$dest"
echo "<< CHECKPOINT 2 >>"
grep -rlZ --include='*.yaml' 'kind: ExternalArtifact' . |
  xargs -0 -r -n1 yq -i '(select(.kind == "Kustomization" and .spec.sourceRef.kind == "ExternalArtifact") | .spec.sourceRef) = {"kind": "OCIRepository", "name": "flux-operator", "namespace": "infra-flux"}'
echo "<< CHECKPOINT 3 >>"
# The cluster's kustomize-mutating-webhook adds every cluster-config and cluster-secrets key to each
# Kustomization's postBuild.substitute. Add the same keys valued as their own ${KEY}: placeholders then
# render as-is (secret values are never needed), but an app's own postBuild variables still apply,
# and anything else gets substituted the way the cluster does it.
vars=$(yq -N '(.data // .stringData) | keys | .[]' \
  globals/cluster-config.yaml globals/cluster-secrets.enc.age.yaml |
  sort -u | jq -R . | jq -cs 'map({(.): ("${" + . + "}")}) | add')
export vars
grep -rlZ --include='*.yaml' 'kind: Kustomization' . |
  xargs -0 -r -n1 yq -i '(select(.kind == "Kustomization" and (.apiVersion | test("^kustomize.toolkit.fluxcd.io/"))) | .spec.postBuild.substitute) |= (env(vars) + (. // {}))'
echo "<< CHECKPOINT 4 >>"
# Runtime-only objects with nothing to render offline:
# - flux-instance / flux-operator ResourceSets need the Flux CRDs that the operator installs.
# - The PR-preview ResourceSet takes its inputs from open GitHub PRs.
yq -i 'del(.resources[] | select(. == "helmrelease.yaml"))' applications/infra/flux/app/kustomization.yaml
grep -rlZ --include='*.yaml' 'type: GitHubPullRequest' applications |
  while IFS= read -r -d '' provider; do
    yq -i 'del(.resources[] | select(. == "resourceset.yaml"))' "$(dirname "$provider")/kustomization.yaml"
  done
echo "<< CHECKPOINT 5 - END >>"
