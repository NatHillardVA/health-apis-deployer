#!/usr/bin/env bash

BASE=$(dirname $(readlink -f $0))
. $BASE/config.sh

deleteResources() {
  local type=$1
  local path=$2
  local json="$WORK/deleted-$(echo $type | tr ' ' '-').json"
  echo ============================================================
  echo "Deleting $VERSION $type"
  curl -sk -X DELETE \
    -H "Authorization: Bearer $(oc whoami --show-token)" \
    -o "$json" \
    -w "%{http_code}\n" \
    $(oc whoami --show-server)$path?labelSelector=version=$VERSION
  jq -r ".items[].metadata.name" $json 2>/dev/null
  echo
}

deleteServices() {
  #
  # Services delete doesn't support deleting by selector. We'll have to
  # search by label, then delete each individually
  #
  local path=/api/v1/namespaces/${OPENSHIFT_PROJECT}/services
  echo ============================================================
  echo "Deleting $VERSION Services"
  curl -sk \
    -H "Authorization: Bearer $(oc whoami --show-token)" \
    $(oc whoami --show-server)$path?labelSelector=version=$VERSION \
    | jq -c .items[].metadata.selfLink -r \
    | xargs -I {} bash -c \
      'curl -sk -X DELETE -H "Authorization: Bearer $(oc whoami --show-token)" $(oc whoami --show-server){}'
  echo
}

deleteS3Artifacts() {
  echo ============================================================
  echo "Deleting $VERSION S3 Bucket Artifacts"
  for app in ids mr-anderson argonaut clinician-argonaut
  do
    local resource="s3://$APP_CONFIG_BUCKET/${app}-$VERSION"
    echo "Deleting $resource"
    aws s3 rm $resource --recursive
    [ $? != 0 ] && echo "Failed to delete configuration for $app"
  done
}


loginToOpenShift > /dev/null
deleteResources "routes" /oapi/v1/namespaces/${OPENSHIFT_PROJECT}/routes
deleteServices
deleteResources "deployment configurations" /oapi/v1/namespaces/${OPENSHIFT_PROJECT}/deploymentconfigs
deleteResources "replication controllers" /api/v1/namespaces/${OPENSHIFT_PROJECT}/replicationcontrollers
deleteResources "pods" /api/v1/namespaces/${OPENSHIFT_PROJECT}/pods
deleteS3Artifacts
exit 0
