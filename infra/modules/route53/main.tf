data "aws_route53_zone" "zone" {
  name = var.root_domain
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [var.app_runner_url]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in var.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.zone.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

variable "domain_name" {
  type = string
}

variable "root_domain" {
  type = string
}

variable "app_runner_url" {
  type = string
}

variable "domain_validation_options" {
  type = any
}
