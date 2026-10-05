output "state_bucket" {
  description = "Name of the S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "Name of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.lock.name
}

output "backend_config_hint" {
  description = "Copy these values into the backend block of the other layers."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    region         = "${var.aws_region}"
    encrypt        = true
  EOT
}
