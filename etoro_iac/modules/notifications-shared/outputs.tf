###############################################################################
# Module outputs
###############################################################################

output "slack_connector_id" {
  description = "ID of the family's Slack connector."
  value       = coralogix_connector.slack.id
}

output "family_preset_id" {
  description = "ID of the family's Notification Center preset."
  value       = coralogix_preset.family.id
}

output "router_ids" {
  description = "Map of environment to the global router ID created for it."
  value       = { for env, r in coralogix_global_router.per_env : env => r.id }
}
