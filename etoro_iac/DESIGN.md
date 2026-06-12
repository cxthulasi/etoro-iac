# Design: Pod_ImagePullBackOff Alert Family

## What this directory does

Generates 894 Coralogix alerts plus 1 Coverage alert from a single Terraform module and one HCL data file.

Each of the 894 alerts watches exactly one `(deployment_environment_name, k8s_cluster_name, k8s_namespace_name)` group for pods entering `ImagePullBackOff`. The Coverage alert watches whether any group has ImagePullBackOff data without a corresponding alert covering it.

## Why this decomposition

### The constraint we are designing against

Coralogix reports up to 1,000 evaluated series per alert in `cx_alert_evaluation_status`. The pre-decomposition alert (single resource, `by (k8s_cluster_name, k8s_namespace_name, k8s_pod_name, deployment_environment_name, cx_application_name, cx_subsystem_name)`) evaluates 14,630 series. Roughly 92% of the scope is silently unobservable: pods past the 1,000th still fire when they break, but cannot be audited or shown on coverage dashboards.

We confirmed this empirically before designing the fix:

  - **Spillage**: 15 alerts in the eToro tenant currently report exactly 1,000 series in `cx_alert_evaluation_status`. The ImagePullBackOff alert is one of them.
  - **Coverage**: pre-rollout, ~500 groups appear in the source metric with no corresponding alert visible on `cx_alert_evaluation_status`.

### Why we picked (env, cluster, namespace)

A query against the source metric returned 894 distinct permutations of `(deployment_environment_name, k8s_cluster_name, k8s_namespace_name)` carrying ImagePullBackOff data. We took this as the decomposition grain.

Three considerations drove the choice:

1. **Per-alert series count stays bounded.** Each (env, cluster, namespace) alert sees only the deployments and pods within one namespace. Even the largest prod namespaces (`prod-aks-we31/applications`, `prod-aks-trading-ne01/tradingteam`) carry tens to low hundreds of unique pods over time, well below the 1,000 cap. No single alert in this family can recreate the spillage condition under realistic churn.

2. **Routing maps cleanly.** `deployment_environment_name` becomes the `routing.environment` label, and Notification Center routes on it. Prod, stg, dev, int, qa, and the case-variant `Stg` each get their own router and JSM target. The decoupling story for Nir: alert PromQL never changes when routing changes.

3. **Maintenance is constant-time per change.** Adding a new cluster or namespace means appending one entry to `locals_alerts.tf` and running `terraform apply`. The module re-generates the alert and the Coverage alert immediately reports the gap closed.

### Why we did not pick coarser or finer grain

**Coarser: (env, cluster), namespace inside the PromQL.** Roughly 60 alerts instead of 894. Smaller resource count, but loses namespace-level routing precision. The deciding factor is operational: when a single pod stuck in ImagePullBackOff fires the alert, the operator needs to know which namespace at minimum. Having namespace as a `keyValues` group in a single per-cluster alert technically supplies this, but a per-cluster alert sees more series per evaluation, which moves us closer to the cap rather than further from it. Rejected.

**Finer: (env, cluster, namespace, cx_subsystem_name).** Would produce several thousand alerts. Excessive for the value gained. Most namespaces have small subsystem counts, so per-namespace alerts already give per-subsystem visibility in the `group_by` of the notification payload. Rejected.

### What happens when new things appear

This is the durability question. The answer is different for each dimension:

  - **New `cx_application_name`.** Nothing changes. It flows through automatically via `group_by` into the notification payload. No JSON edit, no `terraform apply`.

  - **New `cx_subsystem_name`.** Same as above.

  - **New `k8s_namespace_name` in an existing cluster.** Requires one new entry in `locals_alerts.tf`. The Coverage alert detects this within 30 minutes of the new namespace producing ImagePullBackOff data, pages SRE, and the entry is added. Constant-time maintenance.

  - **New `k8s_cluster_name`.** Same as new namespace, multiplied by the number of namespaces in that cluster. Bulk add when a cluster is provisioned.

  - **New `deployment_environment_name`.** Requires entries plus a new routing target in Notification Center. Rare event; expect once or twice per year.

  - **Ephemeral PR-test namespaces (`testenv-pr-XXXX`, `coakvb-XXXX`, etc).** These appear and disappear within hours during stack churn. The 30-minute sustain on the Coverage alert prevents paging on transients. If a PR test environment is genuinely stuck for 30+ minutes, that is by definition a problem worth paging.

## Label propagation scheme

Each Alerting alert carries these labels in its Terraform `labels {}` block. They surface on `cx_alert_evaluation_status` as `cx_alert_def_label_*`.

| Label | Value Source | Purpose |
|-------|--------------|---------|
| `alert_family` | Hardcoded: `Pod_ImagePullBackOff` | Scopes Coverage queries to this family. Regex-matchable for cross-family views (`Pod_.+`). |
| `deployment_environment_name` | Per entry: `each.value.env` | Surfaces the env on evaluation_status; used by Coverage. |
| `k8s_cluster_name` | Per entry: `each.value.cluster` | Surfaces the cluster on evaluation_status; used by Coverage. |
| `k8s_namespace_name` | Per entry: `each.value.namespace` | Surfaces the namespace on evaluation_status; used by Coverage. |
| `routing.environment` | Per entry: `each.value.env` | Routes notification via Notification Center. |
| `created_by` | Hardcoded: `migration_team` | Audit trail. |
| `migrated_from` | Hardcoded: `datadog` | Audit trail; matches existing eToro convention. |

The Coverage alert carries a slightly different set: `alert_family`, `alert_kind = "coverage"`, `routing.environment = "ops"`, and `created_by`.

## What is NOT in this design

  - **Per-service routing labels.** `cx_application_name` and `cx_subsystem_name` flow through `group_by` only, not as alert-level labels. Each namespace contains multiple application/subsystem values, so a single static value at the alert level would be lossy. If service-level routing becomes a requirement, it lives in Notification Center, not in alert labels.

  - **Notification Center wiring.** This Terraform plans and applies the alerts. The Notification Center configuration (which JSM webhook receives which env's notifications) is a separate concern, applied separately, and bound by name string. See the registry guide referenced in the prompt: https://registry.terraform.io/providers/coralogix/coralogix/latest/docs/guides/notification-center

  - **State backend.** Local for the prototype. S3 backend stanza is commented in `versions.tf` for the rollout.

## Threshold tuning

Default: `>= 2` pods entering ImagePullBackOff per minute, sustained for 100% of the last 15 minutes.

The default of 2 (rather than 1) suppresses the case where a single pod fails an image pull during deployment, retries, and recovers. ImagePullBackOff is sticky once it commits, so a sustained reading of 2+ over 15 minutes indicates a genuine problem (image not available, registry credentials wrong, image tag missing) rather than transient pull failure.

Override mechanism: any entry in `local.alerts` can supply an optional `threshold` field. The two `testenv-pr-*` entries in `locals_alerts.tf` use `threshold = 10` because PR test environments produce transient ImagePullBackOff during deploy churn and would otherwise generate noise. Only `threshold` is overrideable. Everything else (PromQL structure, sustain duration, sustain percentage, priority, missing-value handling) is uniform across the family.
