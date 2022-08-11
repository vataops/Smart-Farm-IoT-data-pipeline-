output "pseudo-api-gw-endpoint" {
    value = "${aws_api_gateway_stage.test-s1.invoke_url}/resource"
    description = "Endpoint for pseudo-api-gw resource"
}

output "grafana-ec2-public-dns" {
    value = "http://${aws_instance.grafana-ec2-final.public_dns}:3000"
    description = "Public IPv4 DNS for EC2 instance running Grafana"
}

output "grafana-public-domain-address" {
    value = "${aws_route53_record.www.name}:3000"
    description = "Public domain address for Grafana service"
}