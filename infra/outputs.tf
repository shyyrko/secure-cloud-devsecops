output "app_public_ip" {
  description = "Public IP of the app instance."
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "URL to reach the app (from your allowed IP)."
  value       = "http://${aws_instance.app.public_ip}:8080/healthz"
}

output "logs_bucket" {
  description = "S3 bucket holding CloudTrail audit logs."
  value       = aws_s3_bucket.logs.id
}
