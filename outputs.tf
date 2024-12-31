output "s3_bucket_name" {
  value = aws_s3_bucket.project_bucket.bucket
}

output "ftp_credentials" {
  value = aws_secretsmanager_secret_version.ftp_credentials_version.secret_string
}

output "ftp_server_url" {
  value = "ftp://${random_string.ftp_username.result}:${random_password.ftp_password.result}@${aws_instance.ftp_server.public_ip}:${random_integer.ftp_port.result}"
}

output "ftp_server_address" {
  value = aws_instance.ftp_server.public_ip
}

output "ftp_username" {
  value = random_string.ftp_username.result
}

output "ftp_password" {
  value = random_password.ftp_password.result
}
