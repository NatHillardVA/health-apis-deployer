#!/usr/bin/env bash

BASE=$(dirname $(readlink -f $0))
. $BASE/config.sh

PULL_FILTER='(Preparing|Waiting|already exists)'
APPS="
  health-apis-ids
  health-apis-mr-anderson
  health-apis-argonaut
"

openShiftImageName() {
  echo "${OPENSHIFT_REGISTRY}/${OPENSHIFT_PROJECT}/${1}:${HEALTH_APIS_VERSION}"
}

export IMAGE_IDS=${OPENSHIFT_INTERNAL_REGISTRY}/${OPENSHIFT_PROJECT}/health-apis-ids:${HEALTH_APIS_VERSION}
export IMAGE_MR_ANDERSON=${OPENSHIFT_INTERNAL_REGISTRY}/${OPENSHIFT_PROJECT}/health-apis-mr-anderson:${HEALTH_APIS_VERSION}
export IMAGE_ARGONAUT=${OPENSHIFT_INTERNAL_REGISTRY}/${OPENSHIFT_PROJECT}/health-apis-argonaut:${HEALTH_APIS_VERSION}

printGreeting() {
  env | sort
  echo ============================================================
  echo "Upgrading Health APIs in $ENVIRONMENT to $VERSION"
  cat $ENV_CONF | sort
  echo "Build info"
  cat $BUILD_INFO | sort
  echo "Configuration"
  cat $CONF | sort
}

pullImages() {
  echo ============================================================
  docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD" "$DOCKER_SOURCE_REGISTRY"
  for app in $APPS; do docker pull $DOCKER_SOURCE_ORG/${app}:${HEALTH_APIS_VERSION} | grep -vE "$PULL_FILTER"; done
  docker pull $DOCKER_SOURCE_ORG/health-apis-sentinel:${HEALTH_APIS_VERSION} | grep -vE "$PULL_FILTER"
  docker logout "$DOCKER_SOURCE_REGISTRY"
}

pushToOpenShiftRegistry() {
  echo ============================================================
  echo "Updating images in $OPENSHIFT_URL ($OPENSHIFT_REGISTRY)"
  oc login "$OPENSHIFT_URL" -u "$OPENSHIFT_USERNAME" -p "$OPENSHIFT_PASSWORD" --insecure-skip-tls-verify
  oc project $OPENSHIFT_PROJECT
  docker login -p $(oc whoami -t) -u unused $OPENSHIFT_REGISTRY
  for app in $APPS
  do
    local image=$(openShiftImageName $app)
    # Deploy the new image
    echo ------------------------------------------------------------
    echo "Pushing new $app images ..."
    echo "Tagging new ${image}"
    docker tag $DOCKER_SOURCE_ORG/${app}:$HEALTH_APIS_VERSION ${image}
    echo "Pushing new ${image}"
    docker push ${image} | grep -vE "$PULL_FILTER"
  done
  docker logout $OPENSHIFT_REGISTRY
}

createOpenShiftConfigs() {
  loginToOpenShift
  echo ============================================================
  for TEMPLATE in $(find $BASE/$1 -type f -name "*.yaml")
  do
    CONFIGS=$WORK/$(basename $TEMPLATE)
    cat $TEMPLATE | envsubst > $CONFIGS
    echo ----------------------------------------------------------
    echo $CONFIGS
    cat $CONFIGS
    echo ---------------------------------------------------------
    set -x
    oc create -f $CONFIGS
  done
}

createApplicationConfigs() {
  local ac=$WORK/application-configs
  mkdir -p $ac
  for template in $(find $BASE/application-properties/$APP_CONFIG -name "*.properties")
  do
    local name=$(basename $template);
    local target=$ac/${name%.*}-$VERSION
    mkdir -p $target
    cat $template | envsubst > $target/application.properties
  done
  (cd $ac && aws s3 cp . s3://$APP_CONFIG_BUCKET/ --recursive)
}

printGreeting
pullImages
createApplicationConfigs
loginToOpenShift
pushToOpenShiftRegistry
createOpenShiftConfigs "deployment-configs"
createOpenShiftConfigs "service-configs"
