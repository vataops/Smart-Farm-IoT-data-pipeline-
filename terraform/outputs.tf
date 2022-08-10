output "pseudo-api-gw-endpoint" {
    value = "${aws_api_gateway_stage.test-s1.invoke_url}/resource"
    description = "Endpoint for pseudo-api-gw resource"
}