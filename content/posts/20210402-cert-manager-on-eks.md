+++
date = "2021-04-02"
title = "Integrating Cert Manager with Route53 on EKS"
tags = [
    "aws",
    "route53",
    "devops",
    "eks",
    "cert-manager",
    "kubernetes"
]
categories = [
    "AWS",
    "Kubernetes"
]
+++

## Integrating Cert Manager with Route53 on EKS

In this article I will show, how you can automatically get Let's Encrypt SSL certificates using Cert Manager. We will leverage the DNS01 challange and use a Route53 Hosted Zone to answer the challange. The Cert Manager will use an EKS IAM Role Service Account, which follows AWS best practises for security.

## Setup the EKS cluster with Terraform

We will use this [EKS module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws) to provision our EKS cluster. You have to set the `enable_irsa` parameter to `true`. This registers the EKS clusters OpenID Connect server as on provider for the AWS IAM, which allows Kubernetes service accounts to assume IAM roles on our AWS account.

We also create an IAM role for the Cert Manager service account, which has permissions to the Route53 Hosted Zone.

```terraform
# Variables
variable "name" {
  type = string
}

variable "domain_name" {
  type = string
}

# Providers

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

# VPC

locals {
  eks_cluster_name        = "${var.name}-eks"
  route53_zone_id = module.zones.this_route53_zone_zone_id[var.domain_name]
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.name}-vpc"
  cidr = "10.0.0.0/8"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.0.0/23", "10.0.2.0/23", "10.0.4.0/23"]
  public_subnets  = ["10.0.100.0/23", "10.0.102.0/23", "10.0.104.0/23"]

  enable_dns_hostnames = true

  enable_nat_gateway = true
  single_nat_gateway = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_name}" : "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}-eks" : "shared"
  }

  tags = local.tags
}

# EKS

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.eks_cluster_name
  cluster_version = "1.18"

  vpc_id  = module.vpc.vpc_id
  subnets = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  manage_aws_auth = true
  enable_irsa = true

  worker_groups = [
    {
      instance_type        = "t3a.medium"
      asg_max_size         = 2
      asg_desired_capacity = 2
      root_volume_type     = "gp2"
      subnets              = module.vpc.private_subnets
    }
  ]
}

# Route53 Hosted Zone

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 1.0"

  zones = {
    (var.domain_name) = {
    }
  }
}

# IAM Role Service Account for the cert-manager

module "cert_manager_irsa" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "3.6.0"
  create_role                   = true
  role_name                     = "${var.name}-cert_manager-irsa"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cert_manager_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:cert-manager:cert-manager"]
}

resource "aws_iam_policy" "cert_manager_policy" {
  name        = "${var.name}-cert-manager-policy"
  path        = "/"
  description = "Policy, which allows CertManager to create Route53 records"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "route53:GetChange",
        "Resource" : "arn:aws:route53:::change/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        "Resource" : "arn:aws:route53:::hostedzone/${local.route53_zone_id}"
      },
    ]
  })
}

output "route53_zone_id" {
  value = local.route53_zone_id
}

output "cert_manager_irsa_role_arn" {
  value = module.cert_manager_irsa.this_iam_role_arn
}

```

{{<
  figure
  src="/images/20210402-cert-manager-on-eks/eks_oidc_provider.png"
  link="/images/20210402-cert-manager-on-eks/eks_oidc_provider.png"
>}}

## Deploy Cert Manager

```yaml
#values.yml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: {{cert-manager-iam-role-arn}}

securityContext:
  enabled: true
  fsGroup: 1001
```

```yaml
apiVersion: cert-manager.io/v1beta1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: {{your-email}}
    privateKeySecretRef:
      name: letsencrypt
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
      - dns01:
          route53:
            region: {{your-aws-region}}
            hostedZoneID: {{your-hosted-zone-id}}
```

```bash
helm repo add jetstack https://charts.jetstack.io
helm upgrade cert-manager jetstack/cert-manager \
  --install \
  --namespace cert-manager \
  --create-namespace \
  --values "values.yml" \
  --set installCRDs=true \
   --wait
```

## Deploy an ingress controller

## Test the setup

##

## Read more

- https://cert-manager.io/docs/configuration/acme/dns01/route53/
- https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- https://docs.aws.amazon.com/eks/latest/userguide/best-practices-security.html
