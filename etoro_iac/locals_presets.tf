###############################################################################
# Notification Center preset data (customer-editable).
#
# This file is data, not logic. It defines the Slack message template (heading
# + body) used for every alert in the Pod_ImagePullBackOff family. To change
# how notifications look, edit only this file.
#
# Fields (all optional; sensible defaults are applied in the module):
#   id             - Stable preset ID. Defaults to "<family_slug>_preset".
#   connector_type - Notification connector type. Defaults to "slack".
#   parent_id      - System parent preset. Defaults to the Slack basic preset.
#   title_template - Message heading. Defaults to a family-aware title:
#                    "{{alert.status}} {{alertDef.priority}} - <family> - {{alertDef.name}}"
#   body_template  - Message body. Defaults to the family alert_description
#                    template defined in main.tf (alert.groups context).
#
# Leaving title_template / body_template unset (the default below) is the
# recommended path: the body is taken from alert_description in main.tf so the
# alert text and the notification text never drift apart.
###############################################################################

locals {
  family_preset = {
    id = "pod_ipbo_family_preset"

    # Heading reflects the alert family. Override to customize the title line.
    title_template = "{{alert.status}} {{alertDef.priority}} - Pod_ImagePullBackOff - {{alertDef.name}}"

    # body_template intentionally omitted -> the module uses var.alert_description
    # (the body template lives in etoro_iac/main.tf). Set this only to override.
  }
}
