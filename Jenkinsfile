pipeline {
  agent any

  environment {
    AWS_REGION = "eu-west-2"
  }

  options {
    ansiColor('xterm')
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {

    stage('Checkout Repo') {
      steps {
        git branch: 'main', url: 'https://github.com/suraj-tripathi/oneclickinfra.git'
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([ usernamePassword(credentialsId: 'jenkinsdemo', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY') ]) {
          sh '''
            set -euo pipefail
            cd terraform
            terraform init -input=false
            terraform apply -auto-approve
          '''
        }
      }
    }

    stage('Generate Inventory') {
      steps {
        script {
          // Use single-line sh with returnStdout to avoid multiline parsing issues
          def master_ip  = sh(returnStdout: true, script: 'cd terraform && terraform output -raw valkey_master_private_ip').trim()
          def replica_ip = sh(returnStdout: true, script: 'cd terraform && terraform output -raw valkey_replica_private_ip').trim()
          def bastion_ip = sh(returnStdout: true, script: 'cd terraform && terraform output -raw bastion_public_ip').trim()

          writeFile
