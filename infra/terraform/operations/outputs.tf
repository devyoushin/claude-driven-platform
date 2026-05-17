output "vpc_id" {
  description = "Operations VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "Monitoring EKS cluster name"
  value       = aws_eks_cluster.monitoring.name
}

output "eks_cluster_endpoint" {
  description = "Monitoring EKS cluster endpoint"
  value       = aws_eks_cluster.monitoring.endpoint
}

output "sns_topic_arn" {
  description = "SNS topic ARN for general alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_critical_topic_arn" {
  description = "SNS topic ARN for critical alerts"
  value       = aws_sns_topic.critical_alerts.arn
}

output "grafana_access" {
  description = "How to access Grafana"
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring"
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${local.name}-overview"
}
