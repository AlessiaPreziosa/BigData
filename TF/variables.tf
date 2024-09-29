variable "billing" {
  type    = string
  default = "A1234B-A1234B-A1234B"
}

variable "org" {
  type    = number
  default = 000000000000
}

variable "loc" {
  type = object({
    region       = string
    multi_region = string
  })
  default = {
    region       = "asia-south1" # Mumbai
    multi_region = "Asia"
  }
}
