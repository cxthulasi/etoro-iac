###############################################################################
# Pod_ImagePullBackOff family
#
# Generates one Coralogix alert per (env, cluster, namespace) entry in
# local.alerts, plus one Coverage alert for the family.
###############################################################################

module "pod_image_pull_back_off" {
  source = "./etoro_iac/modules/decomposed-alert-family"

  family_name         = "Pod_ImagePullBackOff"
  source_metric       = "k8s_container_status_reason__container_"
  discriminator_label = "k8s_container_status_reason"
  discriminator_value = "ImagePullBackOff"

  default_threshold = 2
  default_priority  = "P2"

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

  alerts = local.alerts
}