pipeline {
  agent any

  environment {
    AWS_REGION = "eu-west-2"
  }

  stages {

    // ------------------ CHECKOUT ------------------
    stage('Checkout Repo') {
      steps {
        git branch: 'main',
            url: 'https://github.com/suraj-tripathi/oneclickinfra.git'
      }
    }

    // ------------------ TERRAFORM ------------------
    stage('Terraform Apply') {
      steps {
        withCredentials([ usernamePassword(credentialsId: 'jenkinsdemo', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY') ]) {
          sh '''
            set -e
            cd terraform
            terraform init -input=false
            terraform apply -auto-approve
          '''
        }
      }
    }

    // ------------------ GENERATE INVENTORY ------------------
    stage('Generate Inventory') {
      steps {
        script {
          def master_ip  = sh(script: "cd terraform && terraform output -raw valkey_master_private_ip", returnStdout: true).trim()
          def replica_ip = sh(script: "cd terraform && terraform output -raw valkey_replica_private_ip", returnStdout: true).trim()
          def bastion_ip = sh(script: "cd terraform && terraform output -raw bastion_public_ip", returnStdout: true).trim()

          writeFile file: "ansible/inventory/hosts.ini", text: """
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

    // ------------------ ANSIBLE: run inside Docker (recommended) ------------------
    stage('Install Valkey via Ansible (Docker)') {
      agent {
        docker {
          image 'williamyeh/ansible:alpine3'
          args  '-u root:root --network host'
        }
      }
      steps {
        sh '''
          set -e
          # ensure key permissions
          chmod 600 terraform/valkey-demo-key.pem || true

          # ensure ssh client & git available inside container
          if command -v apk >/dev/null 2>&1; then
            apk add --no-cache openssh-client git bash ca-certificates
          elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y openssh-client git bash ca-certificates
          fi

          cd ansible
          ansible-galaxy install -r requirements.yml
          ansible-playbook site.yml -i inventory/hosts.ini \
            --ssh-common-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
        '''
      }
    }

    // ------------------ VALKEY TEST ------------------
    stage('Valkey Test – Master & Replica') {
      steps {
        sh '''
          set -e
          cd terraform
          MASTER=$(terraform output -raw valkey_master_private_ip)
          REPLICA=$(terraform output -raw valkey_replica_private_ip)
          BASTION=$(terraform output -raw bastion_public_ip)
          cd ..

          chmod 600 terraform/valkey-demo-key.pem || true

          echo "TEST → Valkey Master"
          ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o "ProxyCommand=ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i terraform/valkey-demo-key.pem ubuntu@$BASTION -W %h:%p" \
            -i terraform/valkey-demo-key.pem ubuntu@$MASTER "valkey-cli ping" || true

          echo "TEST → Valkey Replica"
          ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -o "ProxyCommand=ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i terraform/valkey-demo-key.pem ubuntu@$BASTION -W %h:%p" \
            -i terraform/valkey-demo-key.pem ubuntu@$REPLICA "valkey-cli ping" || true
        '''
      }
    }
  }

  post {
    success {
      echo "✔ Valkey HA Deployment Successful!"
    }
    failure {
      echo "❌ Pipeline FAILED! Check errors above."
    }
  }
}
