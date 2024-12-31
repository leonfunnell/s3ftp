provider "aws" {
  region = "eu-west-2"
}

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
}

resource "aws_s3_bucket" "project_bucket" {
  bucket = "${var.project_name}-${random_string.bucket_suffix.result}"
}

resource "aws_iam_role" "ftp_role" {
  name = "${var.project_name}_ftp_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ftp_policy" {
  name        = "${var.project_name}_ftp_policy"
  description = "Write-only access to S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.project_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ftp_policy_attachment" {
  role       = aws_iam_role.ftp_role.name
  policy_arn = aws_iam_policy.ftp_policy.arn
}

resource "aws_secretsmanager_secret" "ftp_credentials" {
  name = "${var.project_name}_ftp_credentials"
}

resource "aws_secretsmanager_secret_version" "ftp_credentials_version" {
  secret_id     = aws_secretsmanager_secret.ftp_credentials.id
  secret_string = jsonencode({
    username = random_string.ftp_username.result
    password = random_password.ftp_password.result
  })
}

resource "random_string" "ftp_username" {
  length  = 8
  special = false
}

resource "random_password" "ftp_password" {
  length  = 16
  special = true
}

resource "random_integer" "ftp_port" {
  min = 49152
  max = 65535
}

resource "aws_security_group" "ftp_sg" {
  name        = "${var.project_name}_ftp_sg"
  description = "Allow FTP access"

  ingress {
    from_port   = random_integer.ftp_port.result
    to_port     = random_integer.ftp_port.result
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ftp_server" {
  ami           = "ami-0c55b159cbfafe1f0" // Ubuntu Server 20.04 LTS (HVM), SSD Volume Type
  instance_type = "t2.micro"

  iam_instance_profile = aws_iam_instance_profile.ftp_instance_profile.name
  security_groups      = [aws_security_group.ftp_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y vsftpd awscli s3fs
              echo "local_enable=YES" >> /etc/vsftpd.conf
              echo "write_enable=YES" >> /etc/vsftpd.conf
              echo "chroot_local_user=YES" >> /etc/vsftpd.conf
              echo "allow_writeable_chroot=YES" >> /etc/vsftpd.conf
              echo "pasv_min_port=${random_integer.ftp_port.result}" >> /etc/vsftpd.conf
              echo "pasv_max_port=${random_integer.ftp_port.result}" >> /etc/vsftpd.conf
              echo "pasv_address=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /etc/vsftpd.conf
              service vsftpd restart
              useradd -m ${random_string.ftp_username.result}
              echo "${random_string.ftp_username.result}:${random_password.ftp_password.result}" | chpasswd
              mkdir -p /home/${random_string.ftp_username.result}/ftp/files
              chown ${random_string.ftp_username.result}:${random_string.ftp_username.result} /home/${random_string.ftp_username.result}/ftp/files
              echo "local_root=/home/${random_string.ftp_username.result}/ftp" >> /etc/vsftpd.conf
              echo "${random_password.ftp_password.result}" > /etc/passwd-s3fs
              chmod 600 /etc/passwd-s3fs
              s3fs ${aws_s3_bucket.project_bucket.bucket} /home/${random_string.ftp_username.result}/ftp/files -o passwd_file=/etc/passwd-s3fs
              EOF

  tags = {
    Name = "${var.project_name}_ftp_server"
  }
}