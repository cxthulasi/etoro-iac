###############################################################################
# Notification Center connector data (customer-editable).
#
# This file is data, not logic. It defines the Slack connector that the
# Pod_ImagePullBackOff family routes to. To change the destination channel or
# Slack integration, edit only this file.
#
# Fields:
#   integration_id   - Slack integration ID configured in Coralogix
#                      (Settings -> Integrations -> Slack). REQUIRED.
#   channel          - Default Slack channel notifications are posted to.
#   fallback_channel - Channel used if `channel` cannot be resolved.
#                      Omit to reuse `channel`.
#   name             - Optional display name; defaults to "<family> Slack".
###############################################################################

locals {
  slack_connector = {
    name             = "Pod_ImagePullBackOff Slack"
    integration_id   = "7fac61c7-aae7-41d2-b2b6-6f536e9f97d4"
    channel          = "#test-channel-thulasi"
    fallback_channel = "#test-thulasi"
  }
}
