# eToro Coralogix Alerting — Infrastructure as Code

Terraform that manages **Coralogix alerts** and their **Notification Center routing**
(Slack) as code, plus an **AWS CI/CD pipeline** that plans, lints, gets email
approval, and deploys to Coralogix.

The project is built around two ideas:

1. **Alerts are data, not code.** Operators describe *what* to alert on by editing
   plain `locals_*.tf` data files. They never touch Terraform logic.
2. **One notification path per alert family.** Each family gets a single Slack
   connector, a single message preset, and one router per environment — wired
   automatically from the same data that drives the alerts.

---

## Table of contents

- [What this project does](#what-this-project-does)
- [Repository layout](#repository-layout)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick start (local)](#quick-start-local)
- [The Alerts module](#the-alerts-module-decomposed-alert-family)
- [The Notifications module](#the-notifications-module-notifications-shared)
- [How environments and routers scale](#how-environments-and-routers-scale)
- [Slack integration (one-time manual step)](#slack-integration-one-time-manual-step)
- [Adding a new alert family](#adding-a-new-alert-family)
- [CI/CD pipeline (AWS)](#cicd-pipeline-aws)

---

## What this project does

For each **alert family** (e.g. `Pod_ImagePullBackOff`) the project provisions:

| Resource | Count | Purpose |
| --- | --- | --- |
| Metric-threshold alert | one per `(env, cluster, namespace)` entry | The actual condition being monitored |
| Coverage alert | 1 per family | Fires when a group exists in the source metric but has **no** alert watching it — catches drift |
| Spillage alert | 1 per family | Fires when alert evaluation volume spikes abnormally |
| Slack connector | 1 per family | The family's Slack destination |
| Notification preset | 1 per family | The Slack message template (heading + body) |
| Global router | one per environment (+ `ops`) | Routes the family's alerts to the preset, by environment |

All of it is driven from four customer-editable data files in `etoro_iac/`:
`locals_alerts.tf`, `locals_connectors.tf`, `locals_presets.tf`, `locals_routers.tf`.

---

## Repository layout

```
.
├── etoro_iac/                       # ← the canonical Terraform root (deploy this)
│   ├── main.tf                      # Wires the two modules together for the family
│   ├── versions.tf                  # Provider + S3 backend (partial config)
│   │
│   │   # ── Customer-editable DATA files (edit these, nothing else) ──
│   ├── locals_alerts.tf             # The (env, cluster, namespace) alert list
│   ├── locals_connectors.tf         # Slack connector (integration id + channel)
│   ├── locals_presets.tf            # Notification message template
│   ├── locals_routers.tf            # Router ID prefix
│   │
│   └── modules/
│       ├── decomposed-alert-family/ # ALERTS module (alerts + coverage + spillage)
│       └── notifications-shared/    # NOTIFICATIONS module (connector + preset + routers)
│
├── integrations/                    # Coralogix integration definitions (see Slack section)
├── cicd/                            # AWS CodePipeline + CodeBuild to deploy etoro_iac
│
└── notification_option_*/, notification_shared/   # Earlier design explorations (reference only)
```

> The canonical, supported root is **`etoro_iac/`**. The `notification_option_*`
> and `notification_shared` folders are alternative design explorations kept for
> reference and are not part of the deployed stack.

---

## Architecture

```
 locals_alerts.tf  ─┐
 (env/cluster/ns)   │
                    ├──► module "pod_image_pull_back_off"   (decomposed-alert-family)
                    │        └─ N metric alerts + 1 coverage + 1 spillage
                    │
 locals_connectors  │
 locals_presets     ├──► module "pod_ipbo_notifications"    (notifications-shared)
 locals_routers     │        └─ 1 Slack connector
 (derived envs) ────┘        └─ 1 preset (heading + body)
                             └─ 1 global router per environment (+ ops)

         Alerts label routing.environment = <env>  ──►  Router matches it  ──►  Slack
```

The two modules are decoupled: the alerts module knows nothing about Slack, and
the notifications module knows nothing about thresholds. They are joined only by
the family name and the `routing.environment` label.

---

## Prerequisites

- **Terraform >= 1.10** (required for S3 native state locking via `use_lockfile`).
- **Coralogix provider** `coralogix/coralogix ~> 3.1`.
- A Coralogix **API key** with permission to manage alerts and the Notification Center.
- The target tenant region (this project defaults to **AP1** / `coralogix.in`).

The API key is supplied via the `CORALOGIX_API_KEY` environment variable (never
hardcoded):

```bash
export CORALOGIX_API_KEY="cxup_xxxxxxxxxxxxxxxxxxxxxxxx"
```

---

## Quick start (local)

```bash
cd etoro_iac

# Initialise with the S3 backend (values supplied at init time)
terraform init \
  -backend-config="bucket=<your-state-bucket>" \
  -backend-config="key=etoro_iac/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

In normal operation you do **not** run this by hand — the [CI/CD pipeline](#cicd-pipeline-aws)
does it. The commands above are for local development and validation.

---

## The Alerts module (`decomposed-alert-family`)

Produces one metric-threshold alert per `(env, cluster, namespace)` entry, plus a
Coverage alert and a Spillage alert per family. Coralogix infers the PromQL
group-by keys automatically, so no explicit `group_by` is needed.

### Inputs

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `family_name` | `string` | ✅ | — | Family identifier; becomes the `alert_family` label. |
| `source_metric` | `string` | ✅ | — | Metric the family alerts on. |
| `discriminator_label` | `string` | ✅ | — | Label that distinguishes this family on the metric. |
| `discriminator_value` | `string` | ✅ | — | Value of the discriminator label to target. |
| `alert_description` | `string` | ✅ | — | Coralogix-template description applied to every alert. |
| `alerts` | `list(object)` | ✅ | — | The `(env, cluster, namespace, threshold?)` entries. |
| `default_threshold` | `number` | — | `2` | Threshold for entries that don't override it. |
| `default_priority` | `string` | — | `"P2"` | Coralogix priority for the alerts. |

Each `alerts` entry:

```hcl
{
  env       = string           # e.g. "prod"   (also used as the routing.environment label)
  cluster   = string           # e.g. "prod-aks-we31"
  namespace = string           # e.g. "kube-system"
  threshold = optional(number) # overrides default_threshold for this entry only
}
```

### Example

```hcl
module "pod_image_pull_back_off" {
  source = "./modules/decomposed-alert-family"

  family_name         = "Pod_ImagePullBackOff"
  source_metric       = "k8s_container_status_reason__container_"
  discriminator_label = "k8s_container_status_reason"
  discriminator_value = "ImagePullBackOff"

  default_threshold = 2
  default_priority  = "P2"

  alert_description = local.alert_description
  alerts            = local.alerts
}
```

And the data the operator edits in `locals_alerts.tf`:

```hcl
locals {
  alerts = [
    { env = "prod", cluster = "prod-aks-we31", namespace = "kube-system" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "monitoring" },

    # Per-entry threshold override (noisy ephemeral PR-test namespace):
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "testenv-pr-5019", threshold = 10 },
  ]
}
```

> **To add a monitored group:** append one line to `locals_alerts.tf`. Nothing else changes.

---

## The Notifications module (`notifications-shared`)

Reusable Notification Center wiring for **one** family: a Slack connector, a preset
(message heading + body), and one global router per environment. The body template
defaults to the same `alert_description` used by the alerts, so alert text and
notification text never drift apart.

### Inputs

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `family_name` | `string` | ✅ | — | Family this notification set serves; used in IDs and router conditions. |
| `alert_description` | `string` | ✅ | — | Default preset body template. |
| `environments` | `list(string)` | ✅ | — | Environments to route. **Derive automatically** from the alert data. |
| `slack_connector` | `object` | ✅ | — | Slack destination (see below). |
| `family_preset` | `object` | — | `{}` | Message template overrides. |
| `family_router` | `object` | — | `{}` | Router ID prefix. |

`slack_connector` object:

```hcl
{
  integration_id   = string           # REQUIRED — Slack integration ID from Coralogix (see Slack section)
  channel          = string           # REQUIRED — default Slack channel, e.g. "#alerts-prod"
  name             = optional(string) # display name; defaults to "<family> Slack"
  fallback_channel = optional(string) # used if `channel` cannot be resolved
}
```

`family_preset` object (all optional):

```hcl
{
  id              = optional(string)                              # defaults to "<family_slug>_preset"
  connector_type  = optional(string, "slack")
  parent_id       = optional(string, "preset_system_slack_alerts_basic")
  entity_sub_type = optional(string)  # null = match ALL alert entities (recommended)
  title_template  = optional(string)  # message heading
  body_template   = optional(string)  # defaults to var.alert_description
}
```

`family_router` object:

```hcl
{
  id_prefix = optional(string) # defaults to "<family_slug>_router"
}
```

### Example

`main.tf` derives the environment list from the alert data and passes the
customer-editable locals into the module:

```hcl
locals {
  # One router per distinct environment the alerts actually use.
  environments = distinct([for a in local.alerts : a.env])
}

module "pod_ipbo_notifications" {
  source = "./modules/notifications-shared"

  family_name       = local.family_name
  alert_description  = local.alert_description
  environments      = local.environments

  slack_connector = local.slack_connector   # from locals_connectors.tf
  family_preset   = local.family_preset      # from locals_presets.tf
  family_router   = local.family_router      # from locals_routers.tf
}
```

The operator edits only the data files:

```hcl
# locals_connectors.tf
locals {
  slack_connector = {
    name             = "Pod_ImagePullBackOff Slack"
    integration_id   = "<slack-integration-id>"   # from Coralogix UI (see below)
    channel          = "#alerts-pod-ipbo"
    fallback_channel = "#alerts-fallback"
  }
}

# locals_presets.tf
locals {
  family_preset = {
    id             = "pod_ipbo_family_preset"
    title_template = "{{alert.status}} {{alertDef.priority}} - Pod_ImagePullBackOff - {{alertDef.name}}"
    # body_template omitted on purpose -> uses alert_description from main.tf
  }
}

# locals_routers.tf
locals {
  family_router = {
    id_prefix = "pod_ipbo_family_router"
  }
}
```

---

## How environments and routers scale

You never maintain a list of environments or routers by hand:

1. Add an alert in `locals_alerts.tf` with a new `env` value.
2. `local.environments = distinct([for a in local.alerts : a.env])` picks it up.
3. The module creates `coralogix_global_router.per_env["<new-env>"]` automatically,
   with `routing.environment = <new-env>` and a rule matching the family.

Because routers use `for_each`, adding an env **adds** one router without touching
the others; removing the last alert for an env **destroys** its router.

Two constraints to be aware of:

- **Routing labels are globally unique per tenant.** A new env router fails to
  create if another router already claims that environment value.
- **Environment values are case-sensitive.** `Stg` and `stg` are distinct metric
  label values, so they legitimately produce two routers. The module
  disambiguates their router IDs automatically (e.g. `..._stg` and `..._stg_1`).

---

## Slack integration (one-time manual step)

The `integration_id` in `locals_connectors.tf` must be a **real Slack integration**
that exists in Coralogix. This integration is created via an OAuth/UI flow and
**cannot be created by Terraform** — only the connector, preset, and routers are
Terraform-managed.

One-time setup:

1. Coralogix → **Data Flow → Integrations → Slack → Add New (v0.1.0)**.
2. Enter a name, choose **Send notifications**, and **Authorize** the Slack workspace.
3. Copy the resulting **integration ID** from the integrations list.
4. Paste it into `locals_connectors.tf` → `integration_id`.

After that, all connector/preset/router changes flow through Terraform as usual.

---

## Adding a new alert family

The notifications module is reusable. To onboard a second family:

1. Add a `decomposed-alert-family` module call with the new family's metric and data.
2. Add a `notifications-shared` module call with that family's connector/preset/router locals.
3. Give the new family a **distinct routing dimension** if it shares environments
   with an existing family (routing labels are globally unique per tenant).

---

## CI/CD pipeline (AWS)

The `cicd/` Terraform stack provisions an AWS pipeline that deploys `etoro_iac`.
Source lives in a CodeCommit repo named **`etoro-iac`**; the pipeline runs
**plan + lint**, waits for an **email approval**, then **applies** to Coralogix.

### Flow

```
CodeCommit (etoro-iac, branch main)
        │  EventBridge on push
        ▼
[ Source ]       pull repo
        ▼
[ PlanAndLint ]  CodeBuild: terraform fmt -check · tflint · terraform validate · terraform plan -out=tfplan
        ▼
[ Approval ]     Manual approval → SNS email to approvers
        ▼
[ Deploy ]       CodeBuild: terraform apply tfplan  →  Coralogix
```

### What it creates

| Resource | Purpose |
| --- | --- |
| `aws_codecommit_repository.etoro_iac` | Source repo `etoro-iac` |
| `aws_s3_bucket.artifacts` | CodePipeline artifact store |
| `aws_s3_bucket.tfstate` | Remote state for `etoro_iac` (S3 native locking) |
| `aws_secretsmanager_secret.coralogix` | `api_key` + `domain`, injected into builds |
| `aws_sns_topic.approvals` + email subs | Approval notifications |
| `aws_codebuild_project.plan` / `.apply` | Plan/lint and apply runners |
| `aws_codepipeline.etoro_iac` | The 4-stage pipeline |
| EventBridge rule + role | Auto-start the pipeline on branch push |

### Key inputs (`cicd/variables.tf`)

| Variable | Default | Description |
| --- | --- | --- |
| `aws_region` | `eu-west-1` | Region for all CI/CD resources. |
| `name_prefix` | `etoro-iac` | Prefix for resource names. |
| `repository_name` | `etoro-iac` | CodeCommit repo name. |
| `repository_branch` | `main` | Branch the pipeline tracks. |
| `terraform_working_dir` | `etoro_iac` | Terraform root to deploy. |
| `terraform_state_key` | `etoro_iac/terraform.tfstate` | S3 state key (decoupled from folder name). |
| `terraform_version` | `1.10.5` | Must be >= 1.10 (S3 native locking). |
| `tflint_version` | `0.53.0` | tflint version for linting. |
| `approval_emails` | `[]` | Emails that receive approval requests. |
| `coralogix_api_key` | — (sensitive) | Stored in Secrets Manager, injected as `CORALOGIX_API_KEY`. |
| `coralogix_domain` | `coralogix.in` | Tenant domain/region (AP1). |

### Deploy the pipeline

```bash
cd cicd
cp terraform.tfvars.example terraform.tfvars   # fill in approval_emails + coralogix_api_key
export TF_VAR_coralogix_api_key="cxup_xxx"      # or set it in terraform.tfvars (gitignored)

terraform init
terraform apply
```

Then:

1. **Confirm the SNS subscription** email(s) so approvers receive requests.
2. Push the project to the `etoro-iac` repo to trigger the first run:

```bash
git remote add codecommit <codecommit_clone_url_http>
git push codecommit main
```

3. When the pipeline reaches **Approval**, approvers click **Approve** in the
   CodePipeline console (linked from the email). The **Deploy** stage then applies
   to Coralogix.

### Credentials & state

- `CORALOGIX_API_KEY` and `CORALOGIX_DOMAIN` live in Secrets Manager
  (`etoro-iac/coralogix`) and are surfaced to builds via the buildspec — no key is
  committed to source.
- Remote state uses an S3 bucket with **native lockfiles** (`use_lockfile=true`);
  no DynamoDB table is required.
- If `etoro_iac` has local state from a prior manual apply, migrate it once with
  `terraform init -migrate-state` (see `cicd/README.md` for the exact command).

---

_Maintained by the CX CoE team. For the alert-decomposition design rationale, see
`etoro_iac/DESIGN.md`._
