variable "account_id" {
    type    = string
}

variable "region" {
    type = string
    default = "ap-northeast-2"
}

variable "HOOK_URL" {
  type = string
  default = "https://discord.com/api/webhooks/1004623011401449472/uN08DBEV4it5J75AVqiloev0T6GLtJw6DoDn2OF_w03lMOobtDo5A6fFQFImV65D_aZz"
}

variable "domain_name" {
  type = string
}