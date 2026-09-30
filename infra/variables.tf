variable "aws_region" {
  default = "eu-west-1"
}

variable "app_name" {
  default = "clover-dashboard"
}

variable "domain_name" {
  description = "The domain name for the dashboard"
  type        = string
}

variable "root_domain" {
  description = "Root domain name in Route 53"
  type        = string
}
