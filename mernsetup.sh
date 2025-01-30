#!/bin/bash

# Variables
PROJECT_ID=$(gcloud config get-value project) # Replace with your GCP project ID
REGION="us-central1"          # Replace with your desired region
ZONE="us-central1-a"          # Replace with your desired zone
VPC_NAME="jenkins-mern-vpc"
SUBNET_NAME="jenkins-mern-subnet"
FIREWALL_SSH_NAME="allow-mern-ssh"
FIREWALL_JENKINS_NAME="allow-mern-jenkins"
JENKINS_VM_NAME="jenkins-mern-vm"
CLUSTER_NAME="express-mern-gke-cluster"
SERVICE_ACCOUNT_NAME="jenkins-mern-gke-access"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Create VPC Network
echo "Creating VPC Network..."
gcloud compute networks create $VPC_NAME --subnet-mode=custom

# Create Subnet
echo "Creating Subnet..."
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --range=10.0.0.0/24 \
  --region=$REGION

# Create Firewall Rules
echo "Creating Firewall Rules..."
# Allow SSH
gcloud compute firewall-rules create $FIREWALL_SSH_NAME \
  --network=$VPC_NAME \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  --description="Allow SSH access"

# Allow Jenkins (port 8080)
gcloud compute firewall-rules create $FIREWALL_JENKINS_NAME \
  --network=$VPC_NAME \
  --allow=tcp:8080 \
  --source-ranges=0.0.0.0/0 \
  --description="Allow Jenkins access"

# Create Service Account for Jenkins to Access GKE
echo "Creating Service Account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
  --display-name="Jenkins GKE Access Service Account"
  
gcloud iam service-accounts keys create ~/jenkins-gke-mern-sa-key.json \
  --iam-account=$SERVICE_ACCOUNT_EMAIL

# Assign Roles to Service Account
echo "Assigning Roles to Service Account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/container.developer"

# Create Jenkins VM Instance
echo "Creating Jenkins VM Instance..."
STARTUP_SCRIPT=$(cat <<EOF
#! /bin/bash

apt update

# Install Java SDK 11
apt-get install -y openjdk-17-jdk kubectl git curl google-cloud-sdk-gke-gcloud-auth-plugin

gcloud container clusters get-credentials express-mern-gke-cluster --zone us-central1-a

# Download and Install Jenkins
wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install jenkins

# Start Jenkins
systemctl start jenkins

# Enable Jenkins to run on Boot
systemctl enable jenkins

curl -sSL https://get.docker.com/ | sh
usermod -aG docker `whoami` 
usermod -aG docker jenkins
systemctl restart jenkins



EOF
)

gcloud compute instances create $JENKINS_VM_NAME \
  --zone=$ZONE \
  --machine-type=e2-medium \
  --subnet=$SUBNET_NAME \
  --network-tier=PREMIUM \
  --maintenance-policy=MIGRATE \
  --service-account=$SERVICE_ACCOUNT_EMAIL \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=http-server,https-server \
  --metadata=startup-script="$STARTUP_SCRIPT" \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-balanced \
  --boot-disk-device-name=$JENKINS_VM_NAME
  
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID\
    --zone=$ZONE\
    --num-nodes=3 \
    --machine-type=e2-medium \
    --disk-size=50
sleep 60

echo "Jenkins VM created successfully!"

# Create static IPs if they don't exist
create_static_ip() {
    local name=$1
    if ! gcloud compute addresses list | grep -q $name; then
        echo "Creating static IP: $name..."
        gcloud compute addresses create $name --region=us-central1  # Use the cluster's region
    fi
}

echo "🌐 Creating static IPs..."
create_static_ip "frontend-static-ip"
create_static_ip "backend-static-ip"
create_static_ip "mongo-express-static-ip"

# Get static IPs
FRONTEND_STATIC_IP=$(gcloud compute addresses describe frontend-static-ip --region=us-central1 --format='get(address)')
BACKEND_STATIC_IP=$(gcloud compute addresses describe backend-static-ip --region=us-central1 --format='get(address)')
MONGO_EXPRESS_STATIC_IP=$(gcloud compute addresses describe mongo-express-static-ip --region=us-central1 --format='get(address)')

echo "Static IPs:"
echo "Frontend: $FRONTEND_STATIC_IP"
echo "Backend: $BACKEND_STATIC_IP"
echo "Mongo Express: $MONGO_EXPRESS_STATIC_IP"
echo "Access Jenkins at: http://$(gcloud compute instances describe $JENKINS_VM_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)'):8080"
