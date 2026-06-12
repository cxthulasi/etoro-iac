###############################################################################
# Module inputs
###############################################################################

variable "family_name" {
  description = "Identifier for the alert family. Becomes cx_alert_def_label_alert_family on cx_alert_evaluation_status. Example: 'Pod_ImagePullBackOff'."
  type        = string
}

variable "source_metric" {
  description = "Name of the source metric the family alerts on. Example: 'k8s_container_status_reason__container_'."
  type        = string
}

variable "discriminator_label" {
  description = "Label on the source metric that distinguishes this family from sibling conditions. Example: 'k8s_container_status_reason'."
  type        = string
}

variable "discriminator_value" {
  description = "Value of the discriminator label this family targets. Example: 'ImagePullBackOff'."
  type        = string
}

variable "default_threshold" {
  description = "Threshold applied to every Alerting alert in the family unless overridden by the entry's optional threshold field."
  type        = number
  default     = 2
}

variable "default_priority" {
  description = "Coralogix priority for every Alerting alert in the family."
  type        = string
  default     = "P2"
}

variable "alert_description" {
  description = "Description block applied to every Alerting alert. Uses Coralogix template syntax referencing alert.groups[0].keyValues."
  type        = string
}

variable "alerts" {
  description = "List of (env, cluster, namespace) entries. Each produces one Alerting alert. The optional threshold field overrides default_threshold for that entry only."
  type = list(object({
    env       = string
    cluster   = string
    namespace = string
    threshold = optional(number)
  }))
}
