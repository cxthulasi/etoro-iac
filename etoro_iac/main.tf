###############################################################################
# Pod_ImagePullBackOff family
#
# - decomposed-alert-family: one Coralogix alert per (env, cluster, namespace)
#   entry in local.alerts, plus one Coverage alert for the family.
# - notifications-shared: the Notification Center wiring (connector, preset,
#   per-environment routers) for the family. This module is reusable across
#   families.
###############################################################################

locals {
  family_name = "Pod_ImagePullBackOff"

  # Body template shared by the alerts and the notification preset, so the
  # alert text and the notification text never drift apart.
  alert_description = <<-EOT
    {% if alert.status == "Triggered" %}
    team: SRE Delivery (For Alerts)
    service: {{ alert.groups[0].keyValues.cx_subsystem_name | default(value="N/A") }}
    Azure tagged team: {{ alert.groups[0].keyValues.cx_application_name | default(value="N/A") }}

    Details:
    Cluster name: {{ alert.groups[0].keyValues.k8s_cluster_name | default(value="N/A") }}
    Namespace: {{ alert.groups[0].keyValues.k8s_namespace_name | default(value="N/A") }}
    Environment: {{ alert.groups[0].keyValues.deployment_environment_name | default(value="N/A") }}
    Deployment: {{ alert.groups[0].keyValues.k8s_deployment_name | default(value="N/A") }}
    Number of pods in ImagePullBackOff: {{ alert.groups[0].details.metricThreshold.avgValueOverThreshold | default(value="N/A") }}
    {% endif %}
  EOT

  # Distinct environments the family's alerts use (drives the per-env routers).
  environments = distinct([for a in local.alerts : a.env])
}

module "pod_image_pull_back_off" {
  source = "./modules/decomposed-alert-family"

  family_name         = local.family_name
  source_metric       = "k8s_container_status_reason__container_"
  discriminator_label = "k8s_container_status_reason"
  discriminator_value = "ImagePullBackOff"

  default_threshold = 2
  default_priority  = "P2"

  alert_description = local.alert_description
  alerts            = local.alerts
}

module "pod_ipbo_notifications" {
  source = "./modules/notifications-shared"

  family_name       = local.family_name
  alert_description = local.alert_description
  environments      = local.environments

  # Customer-editable data lives in locals_connectors.tf / locals_presets.tf /
  # locals_routers.tf.
  slack_connector = local.slack_connector
  family_preset   = local.family_preset
  family_router   = local.family_router
}

###############################################################################
# State moves: the Notification Center resources were relocated from the
# decomposed-alert-family module into notifications-shared. These blocks tell
# Terraform the resources moved (preserving the already-created connector and
# preset) instead of destroying and recreating them.
###############################################################################

moved {
  from = module.pod_image_pull_back_off.coralogix_connector.slack
  to   = module.pod_ipbo_notifications.coralogix_connector.slack
}

moved {
  from = module.pod_image_pull_back_off.coralogix_preset.family
  to   = module.pod_ipbo_notifications.coralogix_preset.family
}

moved {
  from = module.pod_image_pull_back_off.coralogix_global_router.per_env
  to   = module.pod_ipbo_notifications.coralogix_global_router.per_env
}
