pipeline {
  agent any

  environment {
    AWS_REGION = "eu-west-2"
  }

  options {
    // fail fast and keep workspace between stages for venv usability
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
          def master_ip  = sh(script: "cd terraform && terraform output -raw valkey_master_private_ip", returnStdout: true).trim()
          def replica_ip = sh(script: "cd terraform &_
