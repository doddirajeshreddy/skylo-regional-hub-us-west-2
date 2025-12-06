output "cluster_name" {
  description = "Name of the AWS Managed EKS cluster."
  value       = aws_eks_cluster.this.name
}
