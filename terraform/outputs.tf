output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Command to update local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "lgtm_buckets" {
  description = "S3 buckets backing the LGTM stack"
  value       = { for k, b in aws_s3_bucket.lgtm : k => b.id }
}

output "lgtm_role_arns" {
  description = "IAM role ARNs bound to each LGTM backend via Pod Identity"
  value       = { for k, r in aws_iam_role.lgtm : k => r.arn }
}
