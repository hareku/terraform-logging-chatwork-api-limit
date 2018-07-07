provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

# windowsの場合、zip化する時にlambda_functionの中身を圧縮せずにフォルダごと圧縮してしまうため、versionを1.0.0に指定。
# https://github.com/terraform-providers/terraform-provider-archive/issues/12
provider "archive" {
  version = "1.0.0"
}
