#!/usr/bin/env bash
cd $(dirname $(readlink -f $0))/upgraderator

dockerRun() {
  docker run \
    --rm --init \
    -e ENVIRONMENT="$ENVIRONMENT" \
    -e TEST_FUNCTIONAL="$TEST_FUNCTIONAL" \
    -e TEST_CRAWL="$TEST_CRAWL" \
    -e GITHUB_USERNAME_PASSWORD="$GITHUB_USERNAME_PASSWORD" \
    -e DOCKER_SOURCE_REGISTRY="$DOCKER_SOURCE_REGISTRY" \
    -e DOCKER_USERNAME="$DOCKER_USERNAME" \
    -e DOCKER_PASSWORD="$DOCKER_PASSWORD" \
    -e OPENSHIFT_USERNAME="$OPENSHIFT_USERNAME" \
    -e OPENSHIFT_PASSWORD="$OPENSHIFT_PASSWORD" \
    -e OPENSHIFT_QA_API_TOKEN="$OPENSHIFT_QA_API_TOKEN" \
    -e OPENSHIFT_QA_LAB_API_TOKEN="$OPENSHIFT_QA_LAB_API_TOKEN" \
    -e OPENSHIFT_LAB_API_TOKEN="$OPENSHIFT_LAB_API_TOKEN" \
    -e OPENSHIFT_PRD_API_TOKEN="$OPENSHIFT_PROD_API_TOKEN" \
    -e AWS_DEFAULT_REGION=us-gov-west-1 \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    -e QA_IDS_DB_USERNAME="$QA_IDS_DB_USERNAME" \
    -e QA_IDS_DB_PASSWORD="$QA_IDS_DB_PASSWORD" \
    -e PROD_IDS_DB_USERNAME="$PROD_IDS_DB_USERNAME" \
    -e PROD_IDS_DB_PASSWORD="$PROD_IDS_DB_PASSWORD" \
    -e LAB_IDS_DB_USERNAME="$LAB_IDS_DB_USERNAME" \
    -e LAB_IDS_DB_PASSWORD="$LAB_IDS_DB_PASSWORD" \
    -e QA_LAB_IDS_DB_USERNAME="$QA_LAB_IDS_DB_USERNAME" \
    -e QA_LAB_IDS_DB_PASSWORD="$QA_LAB_IDS_DB_PASSWORD" \
    -e QA_CDW_USERNAME="$QA_CDW_USERNAME" \
    -e QA_CDW_PASSWORD="$QA_CDW_PASSWORD" \
    -e PROD_CDW_USERNAME="$PROD_CDW_USERNAME" \
    -e PROD_CDW_PASSWORD="$PROD_CDW_PASSWORD" \
    -e LAB_CDW_USERNAME="$LAB_CDW_USERNAME" \
    -e LAB_CDW_PASSWORD="$LAB_CDW_PASSWORD" \
    -e HEALTH_API_CERTIFICATE_PASSWORD="$HEALTH_API_CERTIFICATE_PASSWORD" \
    -e PROD_HEALTH_API_CERTIFICATE_PASSWORD="$PROD_HEALTH_API_CERTIFICATE_PASSWORD" \
    -e TOKEN=$ARGONAUT_TOKEN \
    -e REFRESH_TOKEN=$ARGONAUT_REFRESH_TOKEN \
    -e CLIENT_ID=$ARGONAUT_CLIENT_ID \
    -e CLIENT_SECRET=$ARGONAUT_CLIENT_SECRET \
    -e LAB_CLIENT_ID="$LAB_CLIENT_ID" \
    -e LAB_CLIENT_SECRET="$LAB_CLIENT_SECRET" \
    -e LAB_USER_PASSWORD="$LAB_USER_PASSWORD" \
    --privileged \
    --group-add 497 \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /var/lib/jenkins/.ssh:/root/.ssh \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/docker:/var/lib/docker \
    -v /etc/docker/daemon.json:/etc/docker/daemon.json \
    $@
  return $?
}

blueGreen() {
 dockerRun --entrypoint /upgraderator/blue-green.sh $IMAGE $@
}

deleteOldVersions() {
  echo ------------------------------------------------------------
  echo Deleting old versions
  #
  # Delete all but the last few versions deployed (except if they are either blue or green)
  #
  local blue=$(blueGreen blue-version)
  local green=$(blueGreen green-version)
  local oldVersions=$(blueGreen list-versions | awk 'NR > 3')
  echo "Found old versions:"
  echo "$oldVersions"
  local deleted=
  for version in $oldVersions
  do
    [ "$version" == "$blue" ] && echo "Keeping blue version $version" && continue
    [ "$version" == "$green" ] && echo "Keeping green version $version" && continue
    deleteVersion $version
    deleted+=" $version"
  done
  echo "Deleted old versions:$deleted"
}

deleteVersion() {
  local version=$1
  local deleteMe="vasdvp/health-apis-upgraderator:$version"
  echo "Deleting $version"
  dockerRun --entrypoint /upgraderator/deleterator.sh $deleteMe
  echo "Deleted $version"
}

#
# Run the upgraderator targeting the given environment
#

echo ============================================================
echo ============================================================
echo ============================================================
[ $# == 0 ] && echo "No ENVIRONMENT specified" && exit 1
ENVIRONMENT=$1 && echo "Upgraderator ENVIRONMENT is: $1"

[ "$ENVIRONMENT" == qa ] && echo "SKIPPING $ENVIRONMENT" && exit 0
[ "$ENVIRONMENT" == qa-lab ] && echo "SKIPPING $ENVIRONMENT" && exit 0
[ "$ENVIRONMENT" == lab ] && echo "SKIPPING $ENVIRONMENT" && exit 0

echo ============================================================
echo ============================================================
echo ============================================================

source build.conf
IMAGE="vasdvp/health-apis-upgraderator:$VERSION"
echo "Running Upgraderator $IMAGE"
dockerRun $IMAGE
[ $? != 0 ] && echo "Oh noes... " && exit 1

deleteOldVersions
echo "Deployment done"
exit 0
