output "s3_bucket_name" {
  value = aws_s3_bucket.project_bucket.bucket
}

output "ftp_credentials" {
  value = aws_secretsmanager_secret_version.ftp_credentials_version.secret_string
  sensitive = true
}

output "ftp_server_url" {
  value = "ftp://${random_string.ftp_username.result}:${random_password.ftp_password.result}@${aws_instance.ftp_server.public_ip}:${random_integer.ftp_port.result}"
  sensitive = true
}

output "ftp_server_address" {
  value = aws_instance.ftp_server.public_ip
}

output "ftp_username" {
  value = random_string.ftp_username.result
  sensitive = true
}

output "ftp_password" {
  value     = random_password.ftp_password.result
  sensitive = true
}

output "ftp_port" {
  value = random_integer.ftp_port.result
}

output "project_name" {
  value = var.project_name
}

output "tf_state_bucket" {
  value = var.tf_state_bucket
}

output "aws_region" {
  value = var.aws_region
}


