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
    "Kubernetes",
    "DevOps"
]
+++

## Integrating Cert Manager with Route53 on EKS

In this article I will show, how you can automatically get Let's Encrypt SSL certificates using Cert Manager. We will leverage the DNS01 challenge and use a Route53 Hosted Zone to answer the challenge. The Cert Manager will use an EKS IAM Role Service Account, which follows AWS best practices for security.

## Set up the EKS cluster with Terraform

We will use this [EKS module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws) to provision our EKS cluster. You have to set the `enable_irsa` parameter to `true`. This registers the EKS clusters OpenID Connect server as a provider for the AWS IAM, which allows Kubernetes service accounts to assume IAM roles on our AWS account.

We also create an IAM role for the Cert Manager service account, which has permissions to the Route53 Hosted Zone.

Create a Terraform module with the following content:

{{< highlight terraform >}}
# Variables
variable "name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "region" {
  type = string
  default = "eu-west-1"
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
  cidr = "10.0.0.0/16"

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
{{</ highlight >}}

```bash
terraform init
terraform apply -var "name=cert-test" -var "domain_name={{your-domain-name}}"
```

Running this Terraform module will create the kubeconfig in the `kubeconfig_{{name}}-eks` file. Set the `KUBECONFIG` environment variable to it:
```
export KUBECONFIG="$PWD/kubeconfig_{{name}}-eks"
```

{{<
  figure
  src="/images/20210402-cert-manager-on-eks/eks_oidc_provider.png"
  link="/images/20210402-cert-manager-on-eks/eks_oidc_provider.png"
  caption="The EKS OIDC provider in AWS IAM created to support IAM roles for Kubernetes service accounts"
>}}

## Deploy an ingress controller

To deploy the ingress controller I will use [ingress-nginx](https://kubernetes.github.io/ingress-nginx/).

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace="ingress-nginx"
```

This is pretty straightforward and does not require any special configuration for the certificates to work. AWS will create a Classic Load Balancer for the ingress controller.

## Deploy Cert Manager

Now let's deploy the CertManager. It will use DNS01 challenges with Route53 to verify, that we are the owner of the domain name. We have to configure two things here:
- IAM role used by the service account to make calls to the AWS API,
- set the challenge type to DNS01 and use the Route53 Hosted Zone for it

The IAM role is configured using an annotation on the ServiceAccount Kubernetes resource. We will use [this](https://github.com/jetstack/cert-manager/tree/master/deploy/charts/cert-manager) Helm chart and using it we can set the annotation with the following values for the Helm chart:
```yaml
#cert-manager-values.yml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: {{cert-manager-iam-role-arn}}

installCRDs: true

# the securityContext is required, so the pod can access files required to assume the IAM role
securityContext:
  enabled: true
  fsGroup: 1001
```

Replace the `{{cert-manager-iam-role-arn}}` with our IAM role ARN from the Terraform output. It should be in the form: `arn:aws:iam::{{AWS_ACCOUNT_ID}}:role/cert-test-cert_manager-irsa`. Now run the Helm chart:

```bash
helm repo add jetstack https://charts.jetstack.io
helm upgrade cert-manager jetstack/cert-manager \
  --install \
  --namespace cert-manager \
  --create-namespace \
  --values "cert-manager-values.yml" \
  --wait
```

Now we have to create an Issuer for the CertManager. We will use Let's Encrypt for issuing the certificates for our services. Here we also configure the challenge type, which will be used for issuing the certificates. Fill the template below with the parameters you got from the Terraform output and create the resource:
```yaml
# cert-issuer.yml
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
kubectl apply -f cert-issuer.yml
```

Now your cluster is ready, and you can start getting certificates for your Ingress resources.

## Test the setup

To test our configuration we will deploy [DokuWiki](https://www.dokuwiki.org/dokuwiki) on our Kubernetes cluster. We have to set an annotation on the Ingress resource to tell CertManager, which Issuer should be used to get the certificate.

Create the following file for the Helm chart values and then run the chart:

```yaml
# by default DokuWiki creates an LoadBalancer service and we do not need this
service:
  type: ClusterIP

ingress:
  enabled: true
  hostname: {{you-dokuwiki-domain}}
  certManager: true
  tls: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt   # use the letsencrypt ClusterIssuer
```

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install dokuwiki bitnami/dokuwiki \
  --namespace default \
  --values dokuwiki-values.yml
```

The last thing is to add an A ALIAS record for the Dokuwiki domain name pointing to the ingress Classic Load Balancer in the Route53 Hosted Zone.

{{<
  figure
  src="/images/20210402-cert-manager-on-eks/hosted_zone_dokuwiki.png"
  link="/images/20210402-cert-manager-on-eks/hosted_zone_dokuwiki.png"
  caption="Creating an A ALIAS "
>}}

After the new DNS entry propagates you should be able to access the domain and see DokuWiki with a Let's Encrypt signed SSL certificate!

```bash
$ kubectl get certificate -n default      
NAME                          READY   SECRET                        AGE
doku.eks.myhightech.org-tls   True    doku.eks.myhightech.org-tls   23m
```

{{<
  figure
  src="/images/20210402-cert-manager-on-eks/dokuwiki.png"
  link="/images/20210402-cert-manager-on-eks/dokuwiki.png"
  caption="Dokuwiki with an Let's Encrypt signed SSL certificate"
>}}

## Read more

- https://cert-manager.io/docs/configuration/acme/dns01/route53/
- https://cert-manager.io/docs/usage/ingress/
- https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- https://docs.aws.amazon.com/eks/latest/userguide/best-practices-security.html
