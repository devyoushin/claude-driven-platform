###############################################################################
# Monitoring Stack - Helm으로 Prometheus + Grafana + AlertManager 배포
###############################################################################

# Namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "purpose"                      = "observability"
    }
  }

  depends_on = [aws_eks_node_group.monitoring]
}

###############################################################################
# kube-prometheus-stack (Prometheus + Grafana + AlertManager 통합)
###############################################################################

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "56.6.2"

  # Prometheus 설정
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "30d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp3"
  }

  # Service Account 메트릭 수집을 위한 추가 scrape config
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].job_name"
    value = "service-account-nodes"
  }

  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].static_configs[0].targets[0]"
    value = "10.10.11.0:9100" # Service VPC node-exporter (예시)
  }

  # Grafana 설정
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = "10Gi"
  }

  set {
    name  = "grafana.persistence.storageClassName"
    value = "gp3"
  }

  # Grafana Ingress (internal ALB)
  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }

  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internal"
  }

  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  # AlertManager 설정
  set {
    name  = "alertmanager.alertmanagerSpec.retention"
    value = "120h"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  values = [
    yamlencode({
      grafana = {
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }]
          }
        }
      }
      alertmanager = {
        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            group_by        = ["alertname", "namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "4h"
            receiver        = "default"
            routes = [
              {
                match    = { severity = "critical" }
                receiver = "critical"
              }
            ]
          }
          receivers = [
            {
              name = "default"
              sns_configs = var.alert_email != "" ? [{
                topic_arn = aws_sns_topic.alerts.arn
                region    = var.region
                subject   = "{{ .GroupLabels.alertname }}"
              }] : []
            },
            {
              name = "critical"
              sns_configs = [{
                topic_arn = aws_sns_topic.critical_alerts.arn
                region    = var.region
                subject   = "[CRITICAL] {{ .GroupLabels.alertname }}"
              }]
            }
          ]
        }
      }
    })
  ]

  depends_on = [aws_eks_node_group.monitoring]
}

###############################################################################
# EBS CSI Driver (for PersistentVolume)
###############################################################################

resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.27.0"

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi.arn
  }

  depends_on = [aws_eks_node_group.monitoring]
}

# GP3 StorageClass
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [helm_release.ebs_csi_driver]
}

###############################################################################
# EBS CSI IAM Role (IRSA)
###############################################################################

data "aws_iam_policy_document" "ebs_csi_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.monitoring.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume.json
  tags               = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# OIDC Provider for IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.monitoring.identity[0].oidc[0].issuer

  tags = module.tags.tags
}
