# S3 FTP Terraform Configuration

This Terraform configuration sets up an S3 bucket, an EC2 instance running an FTP server, and necessary IAM roles and policies. The FTP server allows clients to upload files to a subfolder in the S3 bucket using basic authentication.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed
- AWS credentials configured (e.g., using `aws configure`)

## Configuration

The following input variable is required:

- `project_name`: The name of the project. This will be used to prefix the S3 bucket name and other resources.

## Usage

1. Clone this repository and navigate to the directory:

    ```sh
    git clone <repository-url>
    cd s3ftp
    ```

2. Initialize Terraform:

    ```sh
    terraform init
    ```

3. Apply the Terraform configuration:

    ```sh
    terraform apply -var="project_name=<your_project_name>"
    ```

    Replace `<your_project_name>` with your desired project name.

4. After the apply command completes, Terraform will output the following information:

    - `s3_bucket_name`: The name of the created S3 bucket.
    - `ftp_server_url`: The URL to access the FTP server.
    - `ftp_server_address`: The public IP address of the FTP server.
    - `ftp_username`: The username for FTP access.
    - `ftp_password`: The password for FTP access.

## Outputs

- `s3_bucket_name`: The name of the created S3 bucket.
- `ftp_credentials`: The FTP credentials stored in AWS Secrets Manager.
- `ftp_server_url`: The URL to access the FTP server.
- `ftp_server_address`: The public IP address of the FTP server.
- `ftp_username`: The username for FTP access.
- `ftp_password`: The password for FTP access.

## Cleanup

To destroy the resources created by this configuration, run:

```sh
terraform destroy -var="project_name=<your_project_name>"
```

Replace `<your_project_name>` with the same project name used during apply.

## License

This project is licensed under the MIT License.
