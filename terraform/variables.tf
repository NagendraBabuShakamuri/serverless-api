variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "new_neo"
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/24"
}

variable "lambda_permission_arns" {
  type = map(string)
  default = {
    "healthz_permission" : "/GET/healthz",
    "create_user_permission" : "/POST/v1/user",
    "get_user_permission" : "/GET/v1/user/*",
    "update_user_permission" : "/PUT/v1/user/*",
    "get_product_permission" : "/GET/v1/product/*",
    "create_product_permission" : "/POST/v1/product",
    "put_product_permission" : "/PUT/v1/product/*",
    "patch_product_permission" : "/PATCH/v1/product/*",
    "delete_product_permission" : "/DELETE/v1/product/*",
    "get_images_permission" : "/GET/v1/product/*/image",
    "get_image_permission" : "/GET/v1/product/*/image/*",
    "upload_image_permission" : "/POST/v1/product/*/image",
    "delete_image_permission" : "/DELETE/v1/product/*/image/*"
  }
}

variable "private_subnets" {
  type    = number
  default = 3
}

variable "database" {
  type    = string
  default = "webapp"
}