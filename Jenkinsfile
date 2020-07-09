
/*
 * The supported products of the pipeline.
 * Key: product name
 * Value: List of channels to send slack messages to
 */
def products() {
  products = [:]
  products["none"] = ["health_apis_jenkins"]
  products["bridg"] = ["health_apis_jenkins"]
  products["carma"] = ["health_apis_jenkins"]
  products["carma-bgs"] = ["health_apis_jenkins", "arcadian_achievements"]
  products["carma-cdw"] = ["health_apis_jenkins", "arcadian_achievements"]
  products["carma-fms-connector"] = ["health_apis_jenkins"]
  products["carma-mpi-bulk"] = ["health_apis_jenkins", "arcadian_achievements"]
  products["carma-vssc"] = ["vasdvp_jenkins","arcadian_achievements"]
  products["community-care"] = ["health_apis_jenkins","shankins"]
  products["data-query"] = ["health_apis_jenkins","shankins"]
  products["dmc-vet-search"] = ["health_apis_jenkins"]
  products["email-to-case"] = ["health_apis_jenkins"]
  products["exemplar"] = ["health_apis_jenkins","shankins"]
  products["facilities"] = ["health_apis_jenkins","shankins"]
  products["fall-risk"] = ["health_apis_jenkins", "shankins"]
  products["gal"] = ["health_apis_jenkins"]
  products["gal-processor"] = ["health_apis_jenkins"]
  products["hotline"] = ["health_apis_jenkins"]
  products["logging"] = ["health_apis_jenkins"]
  products["mock-ee"] = ["health_apis_jenkins","shankins"]
  products["mock-vler"] = ["health_apis_jenkins","shankins"]
  products["monitoring"] = ["health_apis_jenkins"]
  products["patsr"] = ["health_apis_jenkins"]
  products["provider-directory"] = ["health_apis_jenkins"]
  products["qms"] = ["health_apis_jenkins"]
  products["sfdc-mvi-ent"] = ["health_apis_jenkins"]
  products["sfdc-mpi-msg-receiver"] = ["health_apis_jenkins"]
  products["sf-d-to-c-handler"] = ["health_apis_jenkins"]
  products["sf-d-to-c-query"] = ["health_apis_jenkins"]
  products["squares"] = ["health_apis_jenkins"]
  products["ssn-sensitivity-vimt"] = ["health_apis_jenkins"]
  products["unifier-kong"] = ["health_apis_jenkins"]
  products["urgent-care"] = ["health_apis_jenkins","shankins"]
  products["watrs"] = ["health_apis_jenkins"]
  return products
}


def saunter(scriptName) {
  withCredentials([
    usernameColonPassword(
      credentialsId: 'GITHUB_USERNAME_PASSWORD',
      variable: 'GITHUB_USERNAME_PASSWORD'),
    usernamePassword(
      credentialsId: 'HEALTH_APIS_RELEASES_NEXUS_USERNAME_PASSWORD',
      usernameVariable: 'NEXUS_USERNAME',
      passwordVariable: 'NEXUS_PASSWORD'),
    usernamePassword(
      credentialsId: 'DOCKER_USERNAME_PASSWORD',
      usernameVariable: 'DOCKER_USERNAME',
      passwordVariable: 'DOCKER_PASSWORD'),
    string(
      credentialsId: 'DOCKER_SOURCE_REGISTRY',
      variable: 'DOCKER_SOURCE_REGISTRY'),
    string(
      credentialsId: 'CRYPTO_KEY',
      variable: 'CRYPTO_KEY'),
    string(
      credentialsId: 'DEPLOYMENT_CRYPTO_KEY',
      variable: 'DEPLOYMENT_CRYPTO_KEY'),
    string(
      credentialsId: 'UC_CRYPTO_KEY',
      variable: 'UC_CRYPTO_KEY'),
    file(
      credentialsId: 'KUBERNETES_QA_SSH_KEY',
      variable: 'KUBERNETES_QA_SSH_KEY'),
    file(
      credentialsId: 'KUBERNETES_UAT_SSH_KEY',
      variable: 'KUBERNETES_UAT_SSH_KEY'),
    file(
      credentialsId: 'KUBERNETES_STAGING_SSH_KEY',
      variable: 'KUBERNETES_STAGING_SSH_KEY'),
    file(
      credentialsId: 'KUBERNETES_PRODUCTION_SSH_KEY',
      variable: 'KUBERNETES_PRODUCTION_SSH_KEY'),
    file(
      credentialsId: 'KUBERNETES_STAGING_LAB_SSH_KEY',
      variable: 'KUBERNETES_STAGING_LAB_SSH_KEY'),
    file(
      credentialsId: 'KUBERNETES_LAB_SSH_KEY',
      variable: 'KUBERNETES_LAB_SSH_KEY')
  ]) {
    sh script: scriptName
  }
}

def sendDeployMessage(channelName) {
  slackSend(
    channel: channelName,
    color: '#4682B4',
    message: "DEPLOYING - ${env.JOB_NAME} ${env.BUILD_NUMBER}\n(<${env.BUILD_URL}|Open>)\n```ENVIRONMENT .......... ${env.ENVIRONMENT}\nPRODUCT .............. ${env.PRODUCT}\nAVAILABILITY_ZONES ... ${env.AVAILABILITY_ZONES}```"
  )
}

def notifyOperationsChannel() {
  return ["lab", "production"].contains(env.ENVIRONMENT)
}

def notifySlackOfDeployment() {
  if (env.PRODUCT != "none" && env.PRODUCT != null) {
    if(notifyOperationsChannel()) {
      sendDeployMessage('api_operations')
    }
    products()[env.PRODUCT].each { sendDeployMessage(it) }
  }
}

pipeline {
  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '99', artifactNumToKeepStr: '99'))
    retry(0)
    timeout(time: 1440, unit: 'MINUTES')
    timestamps()
  }
  parameters {
    booleanParam(name: 'DEBUG', defaultValue: false, description: "Enable debugging output")
    choice(name: 'PRODUCT', choices: products().keySet() as List, description: "Install this product")
    choice(name: 'AVAILABILITY_ZONES', choices: ['automatic','us-gov-west-1a','us-gov-west-1b','us-gov-west-1c'], description: "Automatically install to all known AZs, or to the automatic availability zones configured in the DU deployment.conf. Additionally, you may directly install to a chosen AZ.")
    booleanParam(name: 'DONT_REATTACH_TO_BLUE', defaultValue: false, description: "Leave the load balancer routes and targets attached to green and don't put them back on blue(only available when deploying to a single AZ).")
    booleanParam(name: 'SIMULATE_REGRESSION_TEST_FAILURE', defaultValue: false, description: "Force rollback logic by simulating a test failure.")
    booleanParam(name: 'DANGER_ZONE', defaultValue: false, description: "Perform a build to deploy a DU_VERSION with minimal steps. No testing, or validations.")
    string(name: 'DANGER_ZONE_DU_VERSION', defaultValue: 'default', description: "Manual override of DU_VERSION for DANGER_ZONE." )
    string(name: 'CUSTOM_CLUSTER_ID', defaultValue: 'default', description: 'Override the cluster-id -- **To use this functionality, Jenkins needs access to port 30443 on K8s worker nodes**')
  }
  agent {
    docker {
      registryUrl 'https://index.docker.io/v1/'
      registryCredentialsId 'DOCKER_USERNAME_PASSWORD'
      image 'vasdvp/health-apis-cluster-tools:latest'
      /*
       * We'll use the host user db so that any files written from the docker container look
       * like they were written by real host users.
       *
       * We also want to share the Maven repostory and SSH configuration, and finally we'll
       * need to be able to access docker. For that, we'll need to add the docker group, which
       * is currently 475, we'll need to mount the sock and need access to the rest of docker
       * lib for containers.
       */
      args "--privileged --group-add 497 -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro -v /data/jenkins/.m2/repository:/root/.m2/repository -v /var/lib/jenkins/.ssh:/root/.ssh -v /var/run/docker.sock:/var/saunter/docker.sock -v /var/lib/docker:/var/lib/docker -v /etc/docker/daemon.json:/etc/docker/daemon.json"
    }
  }
  triggers {
    upstream(upstreamProjects: 'department-of-veterans-affairs/health-apis/master', threshold: hudson.model.Result.SUCCESS)
  }
  environment {
    ENVIRONMENT = "${["qa", "uat", "staging", "production", "staging_lab", "lab"].contains(env.BRANCH_NAME) ? env.BRANCH_NAME.replaceAll('_','-') : "qa"}"
    PATH = "$WORKSPACE/bin:$PATH"
  }
  stages {
    stage('Set-up') {
      steps {
        script {
          for(cause in currentBuild.rawBuild.getCauses()) {
            env['BUILD_'+cause.class.getSimpleName().replaceAll('(.+?)([A-Z])','$1_$2').toUpperCase()]=cause.getShortDescription()
          }
          sh script: './initialize.sh'
        }
      }
    }
    stage('Danger Zone!') {
      when {
        beforeInput true
        expression { return env.DANGER_ZONE == 'true' }
      }
      input {
       message "I would like to enter the DANGER_ZONE..."
       ok "You may enter!"
       submitter "aparcel-va,bryan.schofield,evan.clendenning,gabriel.olavarria,ian.laflamme,joshua.hulbert,steven.bair,monica.ramirez"
      }
      steps {
        echo "LANA!!!"
        echo "https://bit.ly/LDcydg"
      }
    }
    stage('Deploy') {
      steps {
        lock("${env.ENVIRONMENT}-deployments") {
          echo "Deployments to ${env.ENVIRONMENT} have been locked"
          //notifySlackOfDeployment()
          saunter('./build.sh')
        }
      }
    }
  }
  post {
    always {
      node('master') {
        archiveArtifacts artifacts: '**/*-logs.zip,**/status.*.json,**/metadata.json', onlyIfSuccessful: false, allowEmptyArchive: true
        script {
          def buildName = sh returnStdout: true, script: '''[ -f .jenkins/build-name ] && cat .jenkins/build-name ; exit 0'''
          currentBuild.displayName = "#${currentBuild.number} - ${buildName}"
          def description = sh returnStdout: true, script: '''[ -f .jenkins/description ] && cat .jenkins/description ; exit 0'''
          currentBuild.description = "${description}"

          def unstableStatus = sh returnStatus: true, script: '''[ -f .jenkins_unstable ] && exit 1 ; exit 0'''
          if (unstableStatus == 1 && currentBuild.result != "FAILURE") {
            currentBuild.result = 'UNSTABLE'
          }

          if (env.PRODUCT != "none" && env.PRODUCT != null) {
            if (notifyOperationsChannel()) {
              //sendNotifications('api_operations')
            }
            //products()[env.PRODUCT].each { sendNotifications(it) }
          }
        }
      }
    }
  }
}
