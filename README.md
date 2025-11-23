
# 🚀 Valkey High Availability (HA) Infrastructure – Automated Deployment

**Terraform + Ansible + Jenkins CI/CD**

This project provisions a fully automated **Valkey High Availability setup** using:

* **Terraform** – AWS VPC, Subnets, EC2, Security Groups, Bastion
* **Ansible** – Configure Valkey Master & Replica
* **Jenkins Pipeline** – End-to-end CI/CD deployment & testing

---

# 🖼️ Infrastructure Diagram (ADD IMAGE HERE)

> **📌 Infrastructure Diagram**


![WhatsApp Image 2025-11-23 at 12 53 10](https://github.com/user-attachments/assets/38d2814f-03cb-45cc-a213-1e16cad2c6d5)


---

# 📌 Project Features

✔ Fully automated Valkey HA deployment
✔ Bastion-based secure SSH tunneling
✔ Private Valkey Master + Replica
✔ Automatic replication configuration
✔ Jenkins-based CI/CD pipeline
✔ Built-in Valkey PING health check

---

# 🏗️ Architecture Overview (Text-based)

```
                ┌───────────────────────────┐
                │       Jenkins Server       │
                └──────────────┬────────────┘
                               │ CI/CD Trigger
                               ▼
                 ┌─────────────────────────┐
                 │        Terraform         │
                 └─────────────┬───────────┘
                               │ Creates
                               ▼
       ┌──────────────────────────────────────────────────┐
       │                     AWS VPC                      │
       │                                                  │
       │  ┌──────────────┐          ┌──────────────────┐  │
       │  │   Bastion     │  SSH     │ Valkey Master     │  │
       │  │ 13.135.72.10  ├─────────▶│ 10.0.2.210       │  │
       │  └──────────────┘          └──────────────────┘  │
       │           │                          ▲           │
       │           ▼                          │           │
       │  ┌──────────────────┐                │           │
       │  │ Valkey Replica     │◀──────────────┘           │
       │  │ 10.0.3.150        │                            │
       │  └──────────────────┘                            │
       └──────────────────────────────────────────────────┘
```

---

# 📂 Project Structure

```
valkey-ha-infra/
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── valkey-demo-key.pem
│
├── ansible/
│   ├── inventory/
│   │   └── hosts.ini
│   ├── site.yml
│   ├── ansible.cfg
│   └── templates/
│       └── valkey.conf.j2
│
├── Jenkinsfile
└── README.md
```

---

# 🔧 Jenkins Pipeline Summary

### **Stage 1: Checkout Repo**

Clones GitHub repository.

### **Stage 2: Terraform Apply**

* Initializes Terraform
* Applies infrastructure
* Returns master/replica/bastion IP outputs

### **Stage 3: Generate Inventory**

Creates inventory dynamically using Terraform outputs.

### **Stage 4: Install Valkey via Ansible**

Sets up:

* Valkey Master
* Valkey Replica
* Replication configuration
* Protected-mode disabled

### **Stage 5: Valkey Testing**

Jenkins performs:

```
valkey-cli ping
```

On both Master & Replica via Bastion using ProxyCommand.

---

# 🧪 Manual Verification (Real Commands)

## 1️⃣ SSH into Valkey Master (via Bastion)

```
ssh -i terraform/valkey-demo-key.pem \
    -o ProxyCommand='ssh -i terraform/valkey-demo-key.pem ubuntu@13.135.72.10 -W %h:%p' \
    ubuntu@10.0.2.210
```

### Expected:

```
ubuntu@ip-10-0-2-210:~$
```

---

## 2️⃣ SSH into Valkey Replica (via Bastion)

```
ssh -i terraform/valkey-demo-key.pem \
    -o ProxyCommand='ssh -i terraform/valkey-demo-key.pem ubuntu@13.135.72.10 -W %h:%p' \
    ubuntu@10.0.3.150
```

---

## 3️⃣ Check Valkey Master Status

```
valkey-cli ping
```

Expected:

```
PONG
```

---

## 4️⃣ Replication Status from Master

```
valkey-cli info replication
```

Expected:

```
role:master
connected_slaves:1
slave0:ip=10.0.3.150,state=online
```

---

## 5️⃣ Replica Sync Status

```
valkey-cli info replication
```

Expected:

```
role:slave
master_host:10.0.2.210
master_link_status:up
```

---

## 6️⃣ Replication Data Test

### On Master:

```
valkey-cli set demo:test "hello-replica"
```

### On Replica:

```
valkey-cli get demo:test
```

Expected:

```
"hello-replica"
```

---

# 🎉 Final Notes

✔ Full Valkey HA setup automated
✔ No manual infra creation
✔ Robust Jenkins CI/CD
✔ Verified Master–Replica replication
✔ Production-ready patterns
