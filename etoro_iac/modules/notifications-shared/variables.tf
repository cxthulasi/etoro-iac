###############################################################################
# notifications-shared module inputs
#
# Reusable Notification Center wiring for ONE alert family: a Slack connector,
# a preset (heading + body), and one global router per environment. Instantiate
# it once per family. Customer-editable data is supplied by the caller (the
# etoro_iac root locals_*.tf files).
###############################################################################

variable "family_name" {
  description = "Alert family this notification set belongs to. Used in resource IDs/names and in the router condition (alert_family == family_name). Example: 'Pod_ImagePullBackOff'."
  type        = string
}

variable "alert_description" {
  description = "Default body template for the preset. Typically the same alert_description applied to the family's alerts, so notification text and alert text stay in sync. Overridable via family_preset.body_template."
  type        = string
}

variable "environments" {
  description = "Environments the family's alerts use (e.g. distinct env values from the alert data). One global router is created per environment; an additional 'ops' router is added for the Coverage alert."
  type        = list(string)
}

variable "slack_connector" {
  description = "Slack connector for the family (the family's Slack collector). integration_id and channel are required; edit them in etoro_iac/locals_connectors.tf."
  type = object({
    name             = optional(string)
    integration_id   = string
    channel          = string
    fallback_channel = optional(string)
  })
}

variable "family_preset" {
  description = "Notification Center preset for the family. title_template is the message heading (reflects the family); body_template defaults to var.alert_description. Edit in etoro_iac/locals_presets.tf."
  type = object({
    id             = optional(string)
    connector_type = optional(string, "slack")
    parent_id      = optional(string, "preset_system_slack_alerts_basic")
    # When null (default) the preset matches ALL alert entities. Set to a
    # tenant-registered sub-type (e.g. a specific alert type) to narrow it.
    entity_sub_type = optional(string)
    title_template  = optional(string)
    body_template   = optional(string)
  })
  default = {}
}

variable "family_router" {
  description = "Per-environment global routers for the family. Routing labels are based on environment (var.environments, plus 'ops' for the Coverage alert). Edit naming in etoro_iac/locals_routers.tf."
  type = object({
    id_prefix = optional(string)
  })
  default = {}
}
