provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "ssh_private_key" {
  name                    = "${var.project_name}_ssh_key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ssh_private_key_version" {
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = tls_private_key.ssh_key.private_key_pem
}

resource "aws_iam_user" "s3fs_user" {
  name = "${var.project_name}_s3fs_user"
}

resource "aws_iam_user_policy" "s3fs_user_policy" {
  name = "${var.project_name}_s3fs_user_policy"
  user = aws_iam_user.s3fs_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.project_bucket.arn}",
          "${aws_s3_bucket.project_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "s3fs_user_key" {
  user = aws_iam_user.s3fs_user.name
}

resource "aws_secretsmanager_secret" "s3fs_user_credentials" {
  name                    = "${var.project_name}_s3fs_user_credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "s3fs_user_credentials_version" {
  secret_id     = aws_secretsmanager_secret.s3fs_user_credentials.id
  secret_string = jsonencode({
    access_key = aws_iam_access_key.s3fs_user_key.id
    secret_key = aws_iam_access_key.s3fs_user_key.secret
  })
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_vpc" "custom" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.project_name}_vpc"
  }
}

resource "aws_subnet" "custom" {
  vpc_id            = aws_vpc.custom.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "${var.project_name}_subnet"
  }
}

resource "aws_internet_gateway" "custom" {
  vpc_id = aws_vpc.custom.id
  tags = {
    Name = "${var.project_name}_igw"
  }
}

resource "aws_route_table" "custom" {
  vpc_id = aws_vpc.custom.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.custom.id
  }
  tags = {
    Name = "${var.project_name}_route_table"
  }
}

resource "aws_route_table_association" "custom" {
  subnet_id      = aws_subnet.custom.id
  route_table_id = aws_route_table.custom.id
}

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
}

resource "aws_s3_bucket" "project_bucket" {
  bucket = "${lower(var.project_name)}-${lower(random_string.bucket_suffix.result)}"
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
  description = "Write and list access to S3 bucket and access to Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.project_bucket.arn}",
          "${aws_s3_bucket.project_bucket.arn}/*"
        ]
      },
      {
        Action = "secretsmanager:GetSecretValue"
        Effect = "Allow"
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}_s3fs_user_credentials-*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ftp_policy_attachment" {
  role       = aws_iam_role.ftp_role.name
  policy_arn = aws_iam_policy.ftp_policy.arn
}

resource "aws_iam_instance_profile" "ftp_instance_profile" {
  name = "${var.project_name}_ftp_instance_profile"
  role = aws_iam_role.ftp_role.name
}

resource "aws_secretsmanager_secret" "ftp_credentials" {
  name                    = "${var.project_name}_ftp_credentials"
  recovery_window_in_days = 0
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
  special = false
}

resource "random_integer" "ftp_port" {
  min = 49152
  max = 65535
}

resource "aws_security_group" "ftp_sg" {
  name        = "${var.project_name}_ftp_sg"
  description = "Allow FTP and SSH access"
  vpc_id      = aws_vpc.custom.id

  ingress {
    from_port   = random_integer.ftp_port.result
    to_port     = random_integer.ftp_port.result
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 10090
    to_port     = 10100
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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.custom.id
  vpc_security_group_ids = [aws_security_group.ftp_sg.id]
  associate_public_ip_address = true
  key_name               = aws_key_pair.deployer.key_name

  iam_instance_profile = aws_iam_instance_profile.ftp_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              exec > /var/log/user_data.log 2>&1
              set -x
              apt-get update
              apt-get upgrade -y
              apt-get install -y vsftpd awscli s3fs jq
              cat <<EOT > /etc/vsftpd.conf
              listen=YES
              listen_port=${random_integer.ftp_port.result}
              listen_ipv6=NO
              pasv_enable=YES
              pasv_max_port=10100
              pasv_min_port=10090
              local_enable=YES
              write_enable=YES
              chroot_local_user=YES
              allow_writeable_chroot=YES
              local_root=/home/${random_string.ftp_username.result}/ftp
              EOT
              service vsftpd restart
              useradd -m ${random_string.ftp_username.result}
              echo "${random_string.ftp_username.result}:${random_password.ftp_password.result}" | chpasswd
              mkdir -p /home/${random_string.ftp_username.result}/ftp/files
              chown ${random_string.ftp_username.result}:${random_string.ftp_username.result} /home/${random_string.ftp_username.result}/ftp/files
              echo "local_root=/home/${random_string.ftp_username.result}/ftp" >> /etc/vsftpd.conf
              S3FS_CREDENTIALS=$(aws secretsmanager get-secret-value --region ${var.aws_region} --secret-id ${var.project_name}_s3fs_user_credentials --query SecretString --output text)
              AWS_ACCESS_KEY_ID=$(echo $S3FS_CREDENTIALS | jq -r '.access_key')
              AWS_SECRET_ACCESS_KEY=$(echo $S3FS_CREDENTIALS | jq -r '.secret_key')
              echo "$${AWS_ACCESS_KEY_ID}:$${AWS_SECRET_ACCESS_KEY}" > /etc/passwd-s3fs
              chmod 600 /etc/passwd-s3fs
              s3fs ${aws_s3_bucket.project_bucket.bucket} /home/${random_string.ftp_username.result}/ftp/files -o passwd_file=/etc/passwd-s3fs -o use_cache=/tmp -o allow_other -o umask=0777 -o url="https://s3-${var.aws_region}.amazonaws.com"
              aws s3 cp /var/log/user_data.log s3://${aws_s3_bucket.project_bucket.bucket}/user_data.log --region ${var.aws_region}
              EOF

  tags = {
    Name = "${var.project_name}_ftp_server"
  }
}