#!/bin/bash

set -e

echo "=============================="
echo "🚀 Valkey One-Click Deployment"
echo "=============================="

echo "[1/6] → Terraform Init"
cd terraform
terraform init -input=false

echo "[2/6] → Terraform Apply (auto approve)"
terraform apply -auto-approve

echo "Extracting Terraform Outputs…"
BASTION_IP=$(terraform output -raw bastion_public_ip)
MASTER_IP=$(terraform output -raw valkey_master_private_ip)
REPLICA_IP=$(terraform output -raw valkey_replica_private_ip)
KEY_PATH=$(terraform output -raw private_key_path)

echo "Terraform Outputs:"
echo "Bastion IP: $BASTION_IP"
echo "Master IP:  $MASTER_IP"
echo "Replica IP: $REPLICA_IP"
echo "Key Path:   $KEY_PATH"

cd ../ansible

echo "[3/6] → Installing Ansible Galaxy roles"
ansible-galaxy install -r requirements.yml

echo "[4/6] → Testing Dynamic Inventory"
ansible-inventory -i inventory.aws_ec2.yml --graph

echo "[5/6] → Running Ansible Playbook"
ansible-playbook site.yml

echo "[6/6] → Deployment Complete!"

echo "======================================"
echo "🎉 Valkey HA Cluster Successfully Deployed"
echo "======================================"

echo "SSH Access:"
echo "Laptop → Bastion:"
echo "ssh -i terraform/valkey-demo-key.pem ubuntu@$BASTION_IP"
echo
echo "Bastion → Master:"
echo "ssh -i ~/.ssh/valkey-demo-key.pem ubuntu@$MASTER_IP"
echo
echo "Bastion → Replica:"
echo "ssh -i ~/.ssh/valkey-demo-key.pem ubuntu@$REPLICA_IP"
echo
echo "Verify Replication:"
echo "valkey-cli info replication"
