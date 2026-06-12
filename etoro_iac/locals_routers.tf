###############################################################################
# Notification Center router data (customer-editable).
#
# This file is data, not logic. The family creates one global router per
# environment, and the router's routing label IS the environment. The list of
# environments is derived automatically from locals_alerts.tf (every distinct
# `env`, plus "ops" for the Coverage alert), so you do NOT maintain it here --
# add an alert entry and its environment router appears automatically.
#
# Fields (optional):
#   id_prefix - Stable prefix for the generated per-environment router IDs.
#               Final IDs look like "<id_prefix>_<env_slug>" (e.g.
#               pod_ipbo_family_router_prod). Defaults to "<family_slug>_router".
###############################################################################

locals {
  family_router = {
    id_prefix = "pod_ipbo_family_router"
  }
}
