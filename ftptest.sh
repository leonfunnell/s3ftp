#!/bin/bash

set -e

# Function to handle errors
error_exit() {
  echo "Error: $1"
  exit 1
}

# Get the FTP server URL and port
echo "Getting FTP server URL..."
ftp_server_url=$(terraform output -raw ftp_server_url) || error_exit "Failed to get FTP server URL"

echo "Getting S3 bucket name..."
s3_bucket_name=$(terraform output -raw s3_bucket_name) || error_exit "Failed to get S3 bucket name"

echo "Getting FTP server address..."
ftp_server_address=$(terraform output -raw ftp_server_address) || error_exit "Failed to get FTP server address"

echo "Getting FTP port..."
ftp_port=$(terraform output -raw ftp_port) || error_exit "Failed to get FTP port"

# Retry mechanism to check if the server is accessible on the port via TCP
for i in {1..10}; do
  if nc -zv $ftp_server_address $ftp_port; then
    echo "FTP server is accessible on port $ftp_port"
    break
  else
    echo "Retry $i: FTP server is not accessible on port $ftp_port"
    sleep 10
  fi
  if [ $i -eq 10 ]; then
    error_exit "FTP server is not accessible on port $ftp_port after multiple attempts"
  fi
done

# Generate a dummy file
echo "Generating dummy file..."
dummy_file="dummy.txt"
echo "This is a test file." > $dummy_file || error_exit "Failed to create dummy file"

# Upload the file to the FTP server
echo "Uploading file to FTP server..."
curl -T $dummy_file $ftp_server_url || error_exit "Failed to upload file to FTP server"

# Check if the file exists in the S3 bucket
echo "Checking if file exists in S3 bucket..."
aws s3 ls s3://$s3_bucket_name/ftp/files/$dummy_file || error_exit "File does not exist in S3 bucket"

# Download the file from the S3 bucket
echo "Downloading file from S3 bucket..."
aws s3 cp s3://$s3_bucket_name/ftp/files/$dummy_file downloaded_$dummy_file || error_exit "Failed to download file from S3 bucket"

# Compare the downloaded file with the locally generated file
echo "Comparing files..."
if cmp -s $dummy_file downloaded_$dummy_file; then
  echo "The files match."
else
  error_exit "The files do not match."
fi

# Clean up
echo "Cleaning up..."
rm $dummy_file downloaded_$dummy_file || error_exit "Failed to clean up files"
