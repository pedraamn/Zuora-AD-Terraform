variable "azure_domain" {
  description = "azure domain name"
  type        = string
  default     = ""
}

variable "managers_file_path" {
  description = "managers csv file path name"
  type        = string
  default     = ""
}

variable "users_file_path" {
  description = "users file path"
  type        = string
  default     = ""
}

variable "groups_file_path" {
  description = "groups file path"
  type        = string
  default     = ""
}

variable "existing_groups_file_path" {
  description = "existing groups file path"
  type        = string
  default     = ""
}

variable "sam_object_id" {
  description = "Sam's objected id"
  type        = string
  default     = ""
}

variable "pedraam_object_id" {
  description = "Pedraam's objected id"
  type        = string
  default     = ""
}

variable "dan_object_id" {
  description = "Dan's objected id"
  type        = string
  default     = ""
}
