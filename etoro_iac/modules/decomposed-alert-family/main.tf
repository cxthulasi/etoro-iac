###############################################################################
# Module: decomposed-alert-family
#
# Emits N Alerting alerts (one per (env, cluster, namespace) entry in var.alerts)
# plus exactly 1 Coverage alert per invocation.
#
# The Coverage alert fires when any group in the source data has no
# corresponding alert reporting on cx_alert_evaluation_status, sustained
# for 30 minutes.
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    coralogix = {
      source  = "coralogix/coralogix"
      version = "~> 3.1"
    }
  }
}

###############################################################################
# Alerting: N alerts, one per entry in var.alerts
###############################################################################

resource "coralogix_alert" "alerting" {
  for_each = {
    for a in var.alerts : "${a.env}__${a.cluster}__${a.namespace}" => a
  }

  name = format(
    "%s - %s / %s / %s",
    var.family_name,
    each.value.env,
    each.value.cluster,
    each.value.namespace,
  )

  description  = var.alert_description
  enabled      = true
  phantom_mode = false

  labels = {
    "alert_family"                = var.family_name
    "deployment_environment_name" = each.value.env
    "k8s_cluster_name"            = each.value.cluster
    "k8s_namespace_name"          = each.value.namespace
    "routing.environment"         = each.value.env
    "created_by"                  = "migration_team"
    "migrated_from"               = "datadog"
  }

  # Omit group_by: Coralogix infers keys from the PromQL `by (...)` clause.
  # Explicit group_by must match inferred order exactly or apply fails.

  notification_group = {
    router = {
      notify_on = "Triggered and Resolved"
    }
  }

  incidents_settings = {
    notify_on = "Triggered and Resolved"
    retriggering_period = {
      minutes = 1440
    }
  }

  type_definition = {
    metric_threshold = {
      metric_filter = {
        promql = format(
          <<-EOT
            sum(increase(%s{
              deployment_environment_name = "%s",
              k8s_cluster_name = "%s",
              k8s_namespace_name = "%s",
              %s = "%s"
            }[1m])) by (
              cx_application_name,
              cx_subsystem_name,
              deployment_environment_name,
              k8s_cluster_name,
              k8s_deployment_name,
              k8s_namespace_name
            )
          EOT
          ,
          var.source_metric,
          each.value.env,
          each.value.cluster,
          each.value.namespace,
          var.discriminator_label,
          var.discriminator_value,
        )
      }

      rules = [
        {
          condition = {
            threshold      = coalesce(each.value.threshold, var.default_threshold)
            for_over_pct   = 100
            of_the_last    = "15_MINUTES"
            condition_type = "MORE_THAN_OR_EQUALS"
          }
          override = { priority = var.default_priority }
        },
      ]

      missing_values = {
        min_non_null_values_pct = 100
      }
    }
  }
}

###############################################################################
# Coverage: 1 alert per family invocation
#
# Fires when groups exist in the source metric but have no corresponding
# alert reporting on cx_alert_evaluation_status. Sustained for 30 minutes
# to absorb ephemeral PR-test namespaces flickering in and out.
###############################################################################

resource "coralogix_alert" "coverage" {
  name = "${var.family_name} - Coverage Gap"

  description  = "One or more (env, cluster, namespace) groups have ${var.discriminator_value} pods in the source metric but no corresponding alert in ${var.family_name}. Add the missing groups to the locals list and apply."
  enabled      = true
  phantom_mode = false

  labels = {
    "alert_family"        = var.family_name
    "alert_kind"          = "coverage"
    "routing.environment" = "ops"
    "created_by"          = "migration_team"
  }

  notification_group = {
    router = {
      notify_on = "Triggered and Resolved"
    }
  }

  incidents_settings = {
    notify_on = "Triggered and Resolved"
    retriggering_period = {
      minutes = 1440
    }
  }

  type_definition = {
    metric_threshold = {
      metric_filter = {
        promql = format(
          <<-EOT
            count(
              group by (deployment_environment_name, k8s_cluster_name, k8s_namespace_name) (
                count_over_time(%s{%s="%s"}[1h])
              )
              unless on (deployment_environment_name, k8s_cluster_name, k8s_namespace_name)
              group by (deployment_environment_name, k8s_cluster_name, k8s_namespace_name) (
                cx_alert_evaluation_status{cx_alert_def_label_alert_family="%s"}
              )
            )
          EOT
          ,
          var.source_metric,
          var.discriminator_label,
          var.discriminator_value,
          var.family_name,
        )
      }

      rules = [
        {
          condition = {
            threshold      = 0
            for_over_pct   = 100
            of_the_last    = "30_MINUTES"
            condition_type = "MORE_THAN"
          }
          override = { priority = "P3" }
        },
      ]

      missing_values = {
        replace_with_zero = true
      }
    }
  }
}


resource "coralogix_alert" "spillage" {
  name = "${var.family_name} -Attention Needed - Alert Spillage Required"

  description  = "Attention Needed - Alert Spillage Required"
  enabled      = true
  phantom_mode = false

  labels = {
    "alert_family"        = var.family_name
    "alert_kind"          = "spillage"
    "routing.environment" = "ops"
    "created_by"          = "migration_team"
  }

  notification_group = {
    router = {
      notify_on = "Triggered and Resolved"
    }
  }

  incidents_settings = {
    notify_on = "Triggered and Resolved"
    retriggering_period = {
      minutes = 1440
    }
  }

  type_definition = {
    metric_threshold = {
      metric_filter = {
        promql = <<-EOT
          sum(count_over_time(cx_alert_evaluation_status[1m])) by (cx_alert_persistent_id, cx_alert_def_name) >= 1000
        EOT
      }

      rules = [
        {
          condition = {
            threshold      = 1
            for_over_pct   = 100
            of_the_last    = "30_MINUTES"
            condition_type = "MORE_THAN"
          }
          override = { priority = "P3" }
        },
      ]

      missing_values = {
        replace_with_zero = true
      }
    }
  }
}