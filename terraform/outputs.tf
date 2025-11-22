output "vpc_id" {
  value = aws_vpc.valkey_vpc.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "valkey_master_private_ip" {
  value = aws_instance.valkey_master.private_ip
}

output "valkey_replica_private_ip" {
  value = aws_instance.valkey_replica.private_ip
}

output "private_key_path" {
  description = "Local path of generated PEM key"
  value       = local_file.valkey_private_key.filename
}

output "s3_bucket_name" {
  value = aws_s3_bucket.valkey_bucket.id
}
