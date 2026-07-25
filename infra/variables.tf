variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Short name used to tag and name resources."
  type        = string
  default     = "secure-notes"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.4/32). App access is locked to this."
  type        = string
  # no default on purpose - must be set so the app isn't open to the world
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro/t3.micro are AWS Free Tier eligible."
  type        = string
  default     = "t3.micro"
}

variable "container_image" {
  description = "Container image the instance pulls and runs (e.g. yourdockerhubuser/secure-notes:latest)."
  type        = string
}
