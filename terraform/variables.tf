variable "aws_region" {
  default = "eu-central-1"
}
variable "aws_profile" {
  default = "kube-the-hard-way"
}
variable "ami_type" {
  # Ubuntu 16.04 ami
  default = "ami-0cc0a36f626a4fdf5"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "key_name" {
  default = "kube_the_hard_way"
}
variable "public_key_path" {
  default = "~/.ssh/kube_the_hard_way.pub"
}