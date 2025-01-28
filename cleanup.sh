#!/bin/bash

# Variables
PROJECT_ID=$(gcloud config get-value project) # Replace with your GCP project ID
REGION="us-central1"          # Replace with your desired region
ZONE="us-central1-a"          # Replace with your desired zone
VPC_NAME="jenkins-vpc"
SUBNET_NAME="jenkins-subnet"
FIREWALL_SSH_NAME="allow-ssh"
FIREWALL_JENKINS_NAME="allow-jenkins"
JENKINS_VM_NAME="jenkins-vm"
SERVICE_ACCOUNT_NAME="jenkins-gke-access"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
CLUSTER_NAME="express-gke-cluster"

# Delete Jenkins VM Instance
echo "Deleting Jenkins VM Instance..."
gcloud compute instances delete $JENKINS_VM_NAME --zone=$ZONE --quiet

# Delete GKE Cluster
echo "Deleting GKE Cluster..."
gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet

# Delete Firewall Rules
echo "Deleting Firewall Rules..."
gcloud compute firewall-rules delete $FIREWALL_SSH_NAME --quiet
gcloud compute firewall-rules delete $FIREWALL_JENKINS_NAME --quiet

# Delete Subnet
echo "Deleting Subnet..."
gcloud compute networks subnets delete $SUBNET_NAME --region=$REGION --quiet

# Delete VPC Network
echo "Deleting VPC Network..."
gcloud compute networks delete $VPC_NAME --quiet

# Delete Service Account
echo "Deleting Service Account..."
gcloud iam service-accounts delete $SERVICE_ACCOUNT_EMAIL --quiet

echo "Cleanup completed!"

