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

    stage('Checkout') {
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
          def master_ip  = sh(returnStdout: true, script: 'cd terraform && terraform output -raw valkey_master_private_ip').trim()
          def replica_ip = sh(returnStdout: true, script: 'cd terraform && terraform output -raw valkey_replica_private_ip').trim()
          def bastion_ip = sh(returnStdout: true, script: 'cd terraform && terraform output -raw bastion_public_ip').trim()

          writeFile file: 'ansible/inventory/hosts.ini', text: """
[valkey_master]
${master_ip}

[valkey_replica]
${replica_ip}

[bastion]
${bastion_ip}

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=../terraform/valkey-demo-key.pem
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../terraform/valkey-demo-key.pem ubuntu@${bastion_ip}"'
"""
        }
      }
    }

    stage('Prepare Python & Ansible') {
      steps {
        sh '''
          set -euo pipefail
          if ! command -v python3 >/dev/null 2>&1; then
            echo "ERROR: python3 not found on agent" >&2
            exit 1
          fi

          rm -rf .venv || true
          if python3 -m venv .venv 2>/tmp/venv_err.log; then
            echo "venv created"
          else
            if ! command -v pip3 >/dev/null 2>&1; then
              echo "pip3 missing; cannot create venv" >&2
              cat /tmp/venv_err.log || true
              exit 1
            fi
            pip3 install --user virtualenv
            export PATH="$HOME/.local/bin:$PATH"
            python3 -m virtualenv .venv
          fi

          . .venv/bin/activate
          pip install --upgrade pip setuptools wheel
          pip install ansible
          ansible-galaxy --version || true
          deactivate
        '''
      }
    }

    stage('Run Ansible Playbook') {
      steps {
        sh '''
          set -euo pipefail
          . .venv/bin/activate
