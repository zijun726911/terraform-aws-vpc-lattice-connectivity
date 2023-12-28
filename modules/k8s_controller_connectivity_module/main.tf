provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster" "cluster" {
  name = "cluster-2"  # Replace with your EKS cluster's name
}

data "aws_eks_cluster_auth" "cluster" {
  name = "cluster-2"  # Replace with your EKS cluster's name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false  # This is set to false to not load the local kubeconfig file
}

resource "helm_release" "gateway_api_controller" {
  name       = "gateway-api-controller"
  repository = "oci://public.ecr.aws/aws-application-networking-k8s"
  chart      = "aws-gateway-controller-chart"
  version    = "v1.0.1"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  namespace = "aws-application-networking-system"
}
