#!/bin/bash

# EKS Private Node Group Creation Script
# Cluster: Interview-DevOps
# Region: ap-southeast-1

# Variables
CLUSTER_NAME="Interview-DevOps"
REGION="ap-southeast-1"
NODEGROUP_NAME="Interview-DevOps-ng1-private"
INSTANCE_TYPE="t2.small"
NODE_MIN=2
NODE_MAX=4
NODE_VOLUME_SIZE=20
SSH_KEY_NAME="Interview-DevOps"

echo "Creating EKS Private Node Group..."
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Node Group: $NODEGROUP_NAME"

# Create the private node group
eksctl create nodegroup \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --name=$NODEGROUP_NAME \
  --node-type=$INSTANCE_TYPE \
  --nodes-min=$NODE_MIN \
  --nodes-max=$NODE_MAX \
  --node-volume-size=$NODE_VOLUME_SIZE \
  --ssh-access \
  --ssh-public-key=$SSH_KEY_NAME \
  --managed \
  --asg-access \
  --external-dns-access \
  --full-ecr-access \
  --appmesh-access \
  --alb-ingress-access \
  --node-private-networking

echo ""
echo "Node Group Creation Initiated!"
echo ""
echo "To verify the node group creation, run:"
echo "eksctl get nodegroup --cluster=$CLUSTER_NAME --region=$REGION"
echo ""
echo "To verify nodes are in private subnets (External IP should be <none>):"
echo "kubectl get nodes -o wide"