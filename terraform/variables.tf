variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "key_pair_name" {
  description = "Existing AWS key pair name for SSH"
  type        = string
}

variable "node_count" {
  description = "Number of managed nodes (Nginx servers)"
  type        = number
  default     = 2
}