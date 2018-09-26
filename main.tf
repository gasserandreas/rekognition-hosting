# Variables
variable "app_region" {}

variable "account_id" {}

variable "app_name" {}

variable "hosted_zone_id" {}

variable "www_domain_name" {}

variable "root_domain_name" {}

variable "www_domain_name_test" {}

variable "root_domain_name_test" {}

# provider
provider "aws" {
  region = "${var.app_region}"
}

# prod
module "certificate" {
  source           = "./acm-certificate"
  root_domain_name = "${var.root_domain_name}"
  www_domain_name  = "${var.www_domain_name}"
}

module "static_hosting" {
  source = "./static-hosting"

  certificate_arn  = "${module.certificate.arn_hosting}"
  app_region       = "${var.app_region}"
  account_id       = "${var.account_id}"
  app_name         = "${var.app_name}"
  www_domain_name  = "${var.www_domain_name}"
  root_domain_name = "${var.root_domain_name}"
  hosted_zone_id   = "${var.hosted_zone_id}"
}

# test
module "certificate_test" {
  source           = "./acm-certificate"
  root_domain_name = "${var.root_domain_name_test}"
  www_domain_name  = "${var.www_domain_name_test}"
}

module "static_hosting_test" {
  source = "./static-hosting"

  certificate_arn  = "${module.certificate_test.arn_hosting}"
  app_region       = "${var.app_region}"
  account_id       = "${var.account_id}"
  app_name         = "${var.app_name}"
  www_domain_name  = "${var.www_domain_name_test}"
  root_domain_name = "${var.root_domain_name_test}"
  hosted_zone_id   = "${var.hosted_zone_id}"
}

# build / deployment

module "artefacts" {
  source = "./artefacts"
  app_region       = "${var.app_region}"
  account_id       = "${var.account_id}"
  app_name         = "${var.app_name}"
  root_domain_name = "${var.root_domain_name}"
}

# define code build role

# develop branch
module "codebuild_role_develop" {
  source = "./codebuild-role"
  app_region       = "${var.app_region}"
  account_id       = "${var.account_id}"
  app_name         = "${var.app_name}"
  role_name = "develop"
}

# define access policies
resource "aws_iam_role_policy" "develop" {
  role        = "${module.codebuild_role_develop.role_name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${module.static_hosting_test.bucket_arn}",
        "${module.static_hosting_test.bucket_arn}/*"
      ]
    }
  ]
}
POLICY
}

# master branch
module "codebuild_role_master" {
  source = "./codebuild-role"
  app_region       = "${var.app_region}"
  account_id       = "${var.account_id}"
  app_name         = "${var.app_name}"
  role_name = "master"
}

# define access policies
resource "aws_iam_role_policy" "master" {
  role        = "${module.codebuild_role_master.role_name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${module.static_hosting.bucket_arn}",
        "${module.static_hosting.bucket_arn}/*",
        "${module.artefacts.bucket_arn}",
        "${module.artefacts.bucket_arn}/*"
      ]
    }
  ]
}
POLICY
}

# 
output "codebuild-role-policy-develop" {
  value = "${module.codebuild_role_develop.role_name}"
}

output "codebuild-role-policy-master" {
  value = "${module.codebuild_role_master.role_name}"
}