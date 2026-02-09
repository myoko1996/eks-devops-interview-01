# EKS Private Node Group Deployment - Interview Technical Exercise

## Overview
This repository contains all the required scripts and Kubernetes manifests to create an EKS private node group and deploy a user management microservice with AWS Classic Load Balancer.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Files Included](#files-included)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Verification Steps](#verification-steps)
5. [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools
- AWS CLI (configured with appropriate credentials)
- kubectl (Kubernetes command-line tool)
- eksctl (EKS command-line tool)

### AWS Resources Required
- VPC with public and private subnets
- NAT Gateway configured for private subnets
- RDS MySQL instance (for the application)
- SSH Key Pair named "Interview-DevOps"

### Verification of Tool Installation
```bash
# Check AWS CLI
aws --version

# Check kubectl
kubectl version --client

# Check eksctl
eksctl version
```

---

## Files Included

1. **create-private-nodegroup.sh** - Script to create EKS private node group
2. **MySQL-externalName-Service.yml** - MySQL external service configuration
3. **UserManagementMicroservice-Deployment-Service.yml** - Application deployment
4. **Kubernets-Secrets.yml** - Database credentials


---

## Step-by-Step Deployment

### Step 1: Create EKS Cluster (if not exists)

```bash
# Create EKS cluster
eksctl create cluster \
  --name Interview-DevOps \
  --region ap-southeast-1 \
  --zones ap-southeast-1a,ap-southeast-1b \
  --without-nodegroup

# Verify cluster creation
eksctl get cluster --name Interview-DevOps --region ap-southeast-1
```

### Step 2: Create Private Node Group

```bash
# Make the script executable
chmod +x create-private-nodegroup.sh

# Execute the script
./create-private-nodegroup.sh

# Wait for node group creation (this may take 10-15 minutes)
# Monitor the progress
eksctl get nodegroup --cluster=Interview-DevOps --region=ap-southeast-1
```

**Alternative: Manual eksctl Command**
```bash
eksctl create nodegroup \
  --cluster=Interview-DevOps \
  --region=ap-southeast-1 \
  --name=Interview-DevOps-ng1-private \
  --node-type=t2.small \
  --nodes-min=2 \
  --nodes-max=4 \
  --node-volume-size=20 \
  --ssh-access \
  --ssh-public-key=Interview-DevOps \
  --managed \
  --asg-access \
  --external-dns-access \
  --full-ecr-access \
  --appmesh-access \
  --alb-ingress-access \
  --node-private-networking
```

### Step 3: Verify Node Group in Private Subnets

```bash
# Get nodes - External IP should show <none>
kubectl get nodes -o wide

# Expected output should show:
# EXTERNAL-IP: <none>  (indicating nodes are in private subnets)
```

### Step 4: Update MySQL External Service

Before deploying, update the MySQL service with your actual RDS endpoint:

```bash
# Edit the file
vim MySQL-externalName-Service.yml

# Update the externalName field with your RDS endpoint
# Example: usermgmtdb.xxxxxxxxxxxxx.ap-southeast-1.rds.amazonaws.com
```

### Step 5: Update Kubernetes Secrets

Update the database credentials if different from defaults:

```bash
# To encode your own credentials
echo -n 'your-username' | base64
echo -n 'your-password' | base64

# Update the values in secrets.yml
```

### Step 6: Deploy All Kubernetes Manifests

```bash
# Deploy in order
kubectl apply -f Kubernetes-Secrets.yml
kubectl apply -f MySQL-externalName-Service.yml
kubectl apply -f UserManagementMicroservice-Deployment-Service.yml
```

**Or deploy all at once:**
```bash
kubectl apply -f .
```

### Step 7: Verify Deployments

```bash
# Check all resources
kubectl get all

# Check secrets
kubectl get secrets

# Check services
kubectl get svc

# Check pods
kubectl get pods

# Get detailed pod information
kubectl get pods -o wide

# Check pod logs
kubectl logs -f <pod-name>
```

---

## Verification Steps

### 1. Verify Node Group in Private Subnets

```bash
# Check nodes external IP (should be <none>)
kubectl get nodes -o wide

# Verify via AWS Console:
# 1. Go to EKS Console
# 2. Select cluster: Interview-DevOps
# 3. Go to Compute tab -> Node Groups
# 4. Click on: Interview-DevOps-ng1-private
# 5. Check Associated Subnets -> Route Table
# 6. Verify internet traffic routes through NAT Gateway (0.0.0.0/0 -> nat-xxxxx)
```

### 2. Verify Classic Load Balancer Creation

```bash
# Get load balancer DNS name
kubectl get svc usermgmt-restapp-clb-service

# Wait for EXTERNAL-IP to show (may take 2-3 minutes)
# Watch the service
kubectl get svc usermgmt-restapp-clb-service -w
```

**Via AWS Console:**
1. Go to EC2 Console
2. Navigate to Load Balancing -> Load Balancers
3. Find the newly created Classic Load Balancer
4. Copy the DNS name

### 3. Verify Target Health

**Via AWS Console:**
1. Go to EC2 Console -> Target Groups
2. Check the health status of registered targets
3. Status should show "healthy"

### 4. Access the Application

```bash
# Get the load balancer DNS
export CLB_DNS=$(kubectl get svc usermgmt-restapp-clb-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$CLB_DNS/usermgmt/health-status

# Or use the full URL
curl http://<your-clb-dns>/usermgmt/health-status
```

**Expected Response:**
```json
{
  "status": "UP",
  "application": "UserManagement Microservice",
  "version": "1.0.0"
}
```

### 5. Additional Verification Commands

```bash
# Describe the CLB service
kubectl describe svc usermgmt-restapp-clb-service

# Check deployment status
kubectl rollout status deployment/usermgmt-microservice

# Get deployment details
kubectl describe deployment usermgmt-microservice

# Check pod logs
kubectl logs -l app=usermgmt-restapp --tail=50

# Get events
kubectl get events --sort-by='.lastTimestamp'
```

---

## Troubleshooting

---

## Architecture Overview

```
Internet
    |
    v
[Classic Load Balancer] (Public Subnet)
    |
    v
[User Management Pods] (Private Subnet Nodes)
    |
    v
[External Name Service]
    |
    v
[RDS MySQL] (Private Subnet)
```

---

## Configuration Summary

| Component | Configuration |
|-----------|---------------|
| Cluster Name | Interview-DevOps |
| Region | ap-southeast-1 |
| Node Group | Interview-DevOps-ng1-private |
| Instance Type | t2.small |
| Min Nodes | 2 |
| Max Nodes | 4 |
| Volume Size | 20 GB |
| Networking | Private (with NAT Gateway) |
| Load Balancer | Classic Load Balancer (CLB) |
| Application Port | 8095 |
| Replicas | 2 |

---

## Security Considerations

1. **Private Node Group**: Worker nodes have no direct internet access
2. **NAT Gateway**: Outbound internet access for updates and image pulls
3. **Kubernetes Secrets**: Database credentials stored as base64 encoded secrets
4. **Security Groups**: Automatically configured by EKS
5. **IAM Roles**: Managed by eksctl with necessary permissions

---

## Cleanup

To remove all resources:

```bash
# Delete Kubernetes resources
kubectl delete -f UserManagementMicroservice-Deployment-Service.yml
kubectl delete -f MySQL-externalName-Service.yml
kubectl delete -f Kubernetes-Secrets.yml

# Delete node group
eksctl delete nodegroup \
  --cluster=Interview-DevOps \
  --region=ap-southeast-1 \
  --name=Interview-DevOps-ng1-private

# Delete cluster (if needed)
eksctl delete cluster \
  --name=Interview-DevOps \
  --region=ap-southeast-1
```

---

## Notes

1. **RDS Endpoint**: Replace the MySQL external service endpoint with your actual RDS instance endpoint
2. **Database Setup**: Ensure the RDS database is accessible from the EKS VPC
3. **Security Groups**: Verify security groups allow traffic from EKS nodes to RDS
4. **Costs**: Remember to delete resources after testing to avoid unnecessary charges
5. **Best Practices**: In production, consider using:
   - Application Load Balancer instead of Classic
   - AWS Secrets Manager/ HCP Vault instead of Kubernetes Secrets
   - Helm charts/ Kustomize for easier management
   - GitOps approach with ArgoCD or Flux

---