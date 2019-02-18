#
# config.sh is a library and configuration script to be sourced by
# top-level utilities.
#

export WORK=$BASE/work
[ ! -d $WORK ] && mkdir -p $WORK

BUILD_INFO=$BASE/build.conf
VERSION_CONF=$BASE/version.conf
ENV_CONF=
[ -z "$ENVIRONMENT" ] && echo "Environment not specified" && exit 1
case $ENVIRONMENT in
  qa) ENV_CONF=$BASE/qa.conf;;
  qa-lab) ENV_CONF=$BASE/qa-lab.conf;;
  *) echo "Unknown environment: $ENVIRONMENT" && exit 1
esac

[ -z "$BUILD_INFO" ] && echo "Build info file not found: $BUILD_INFO" && exit 1
[ ! -f "$VERSION_CONF" ] && echo "Configuration file not found: $VERSION_CONF" && exit 1
. $BUILD_INFO
. $VERSION_CONF
. $ENV_CONF

export DOCKER_SOURCE_ORG=vasdvp

loginToOpenShift() {
  echo ============================================================
  oc login $OPENSHIFT_URL --token $OPENSHIFT_API_TOKEN --insecure-skip-tls-verify=true
  oc project $OPENSHIFT_PROJECT
}
