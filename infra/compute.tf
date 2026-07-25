# EC2 instance that runs the app, plus its IAM role.

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# instance role: can write its own logs, nothing else
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.project_name}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "WriteAppLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.project_name}/*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "${var.project_name}-logs"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.instance.name
}

# lets me open a shell via SSM Session Manager (no SSH key needed)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# public IP is on purpose - it's the only public host and the SG limits it to my IP
resource "aws_instance" "app" { # nosemgrep: terraform.aws.security.aws-ec2-has-public-ip.aws-ec2-has-public-ip
  # checkov:skip=CKV_AWS_88: Public IP is intentional - this is the single public-facing host, and ingress is restricted to one IP by the security group
  # checkov:skip=CKV_AWS_126: Detailed (1-min) monitoring costs extra; basic 5-min monitoring is sufficient for this project
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true
  ebs_optimized               = true

  # require IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  # rebuild the instance when the boot script / image changes
  user_data_replace_on_change = true

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y docker
    systemctl enable --now docker
    docker run -d --restart unless-stopped -p 8080:8080 \
      --name secure-notes ${var.container_image}
  EOT

  tags = { Name = "${var.project_name}-app" }
}
