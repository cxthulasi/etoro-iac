###############################################################################
# Notification Center: one notification per family (shared, reusable module)
#
# For the family it is instantiated for, this module creates:
#   - 1 coralogix_connector     (Slack: the family's Slack collector)
#   - 1 coralogix_preset        (heading reflects the family; body = alert_description)
#   - N coralogix_global_router (one per environment; routing label = environment)
#
# The family's alerts route through the global router (notification_group.router),
# so these routers pick them up by matching the alert_family / routing.environment
# labels.
#
# NOTE: coralogix_global_router routing_labels values are globally unique per
# tenant. Per-environment routers only work if no other router already owns the
# same environment value. For multiple families sharing environments, give each
# family a distinct routing-label dimension.
###############################################################################

locals {
  family_slug = lower(replace(replace(var.family_name, "-", "_"), ".", "_"))

  # Environments to route: every env the family uses plus "ops"
  # (the Coverage alert carries routing.environment = "ops").
  nc_environments = distinct(concat(
    var.environments,
    ["ops"],
  ))

  # id-safe base token per environment (lowercased, "-"/"." -> "_"). Two env
  # values that differ only by case (e.g. "Stg" and "stg" - both real, distinct
  # metric label values) collapse to the same base here...
  nc_env_base = {
    for env in local.nc_environments :
    env => lower(replace(replace(env, "-", "_"), ".", "_"))
  }

  # ...so group envs by base and append a numeric suffix to colliding ones,
  # keeping router IDs unique even when environments differ only by case. The
  # env whose value already equals its base keeps the clean ID (avoids churn on
  # already-created routers).
  nc_base_groups = {
    for env, base in local.nc_env_base :
    base => env...
  }

  nc_env_slug = merge([
    for base, envs in local.nc_base_groups : {
      for idx, env in envs :
      env => (length(envs) == 1 || env == base) ? base : "${base}_${idx + 1}"
    }
  ]...)

  nc_router_id_prefix = coalesce(var.family_router.id_prefix, "${local.family_slug}_router")

  # Heading shown on the notification. Defaults to a family-aware title.
  nc_preset_title = coalesce(
    var.family_preset.title_template,
    "{{alert.status}} {{alertDef.priority}} - ${var.family_name} - {{alertDef.name}}",
  )

  # Body of the notification. Defaults to the family alert_description template.
  nc_preset_body = coalesce(
    var.family_preset.body_template,
    var.alert_description,
  )
}


###############################################################################
# Connector: the family's Slack collector
###############################################################################

resource "coralogix_connector" "slack" {
  id          = "${local.family_slug}_slack"
  type        = "slack"
  name        = coalesce(var.slack_connector.name, "${var.family_name} Slack")
  description = "Slack connector for the ${var.family_name} alert family."

  connector_config = {
    fields = [
      {
        field_name = "integrationId"
        value      = var.slack_connector.integration_id
      },
      {
        field_name = "channel"
        value      = var.slack_connector.channel
      },
      {
        field_name = "fallbackChannel"
        value      = coalesce(var.slack_connector.fallback_channel, var.slack_connector.channel)
      },
    ]
  }
}

###############################################################################
# Preset: shared family notification template (heading + body)
###############################################################################

resource "coralogix_preset" "family" {
  id             = coalesce(var.family_preset.id, "${local.family_slug}_preset")
  name           = var.family_name
  description    = "Shared Notification Center preset for the ${var.family_name} alert family. Cluster, namespace and environment context resolve dynamically from alert.groups."
  entity_type    = "alerts"
  connector_type = var.family_preset.connector_type
  parent_id      = var.family_preset.parent_id

  config_overrides = [
    {
      # Match all alert entities by default. Only narrow to a specific
      # entity_sub_type when one is explicitly provided (sub-type names must be
      # registered in the tenant, e.g. they differ across alert types).
      condition_type = var.family_preset.entity_sub_type == null ? {
        match_entity_type              = {}
        match_entity_type_and_sub_type = null
        } : {
        match_entity_type = null
        match_entity_type_and_sub_type = {
          entity_sub_type = var.family_preset.entity_sub_type
        }
      }
      message_config = {
        fields = [
          {
            field_name = "title"
            template   = local.nc_preset_title
          },
          {
            field_name = "description"
            template   = local.nc_preset_body
          },
        ]
      }
    },
  ]
}

###############################################################################
# Routers: one per environment, routing label = environment
###############################################################################

resource "coralogix_global_router" "per_env" {
  for_each = toset(local.nc_environments)

  id          = "${local.nc_router_id_prefix}_${local.nc_env_slug[each.value]}"
  name        = "${var.family_name} family router - ${each.value}"
  description = "Routes ${var.family_name} alerts with routing.environment = ${each.value} to the family Slack preset."

  routing_labels = {
    environment = each.value
  }

  rules = [
    {
      entity_type = "alerts"
      name        = "family-alerts"
      condition = each.value == "ops" ? (
        "alertDef.entityLabels.alert_kind == \"coverage\" and alertDef.entityLabels.alert_family == \"${var.family_name}\""
        ) : (
        "alertDef.entityLabels.alert_family == \"${var.family_name}\""
      )
      targets = [
        {
          connector_id = coralogix_connector.slack.id
          preset_id    = coralogix_preset.family.id
        },
      ]
    },
  ]
}
