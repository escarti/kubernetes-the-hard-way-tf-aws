variable "aws_region" {
    default = "eu-central-1"
}
variable "aws_profile" {
    default = "hf-sandbox-account"
}
variable "ami_type" {
    # Ubuntu 16.04 ami
    default = "ami-050a22b7e0cf85dd0"
}
variable "instance_type" {
    default = "t2.micro"
}
variable "key_name" {
    default = "hf_infra_sandbox_application_key"
}
variable "public_key_path" {
    default = "~/.ssh/hf_infra_sandbox_application_key.pub"
}