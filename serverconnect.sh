#!/bin/bash

set -e

# Function to handle errors
error_exit() {
  echo "Error: $1"
  exit 1
}

# refresh the terraform state to get the correct server address
echo "Refreshing Terraform state..."
terraform refresh >/dev/null || error_exit "Failed to refresh Terraform state"

# Get the server credentials and pem file name from Terraform
echo "Getting server address..."
server_address=$(terraform output -raw ftp_server_address) || error_exit "Failed to get server address"

echo "Getting PEM file name..."
pem_file_name=$(terraform output -raw project_name)_key.pem || error_exit "Failed to get PEM file name"

# Define the local path for the PEM file
pem_file_path="./$pem_file_name"

# Delete the existing PEM file if it exists
if [ -f "$pem_file_path" ]; then
  echo "Deleting existing PEM file..."
  rm -f $pem_file_path || error_exit "Failed to delete existing PEM file"
fi

# Get the SSH private key from Secrets Manager
echo "Retrieving SSH private key from Secrets Manager..."
aws secretsmanager get-secret-value --secret-id $(terraform output -raw project_name)_ssh_key --query SecretString --output text > $pem_file_path || error_exit "Failed to retrieve SSH private key from Secrets Manager"

# Set the correct permissions for the PEM file
chmod 400 $pem_file_path || error_exit "Failed to set permissions for PEM file"

# Download the user_data.log file for inspection
echo "Downloading user_data.log file..."
scp -i $pem_file_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$server_address:/var/log/user_data.log ./user_data.log || error_exit "Failed to download user_data.log file"

# Make an interactive SSH connection to the EC2 instance
echo "Connecting to the EC2 instance..."
ssh -i $pem_file_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$server_address || error_exit "Failed to connect to the EC2 instance"

