# etoro-imagepullbackoff

Terraform that generates Coralogix alerts for the `Pod_ImagePullBackOff` family across all eToro environments.

Outputs from a single `terraform apply`:
  - 894 Alerting alerts, one per `(env, cluster, namespace)` group
  - 1 Coverage alert for the family

## Layout

```
.
├── DESIGN.md                          # Why this decomposition, what it covers
├── README.md                          # This file
├── main.tf                            # Module instantiation
├── locals_alerts.tf                   # The 894-entry decomposition data
├── terraform.tfvars                   # (empty for the prototype)
├── versions.tf                        # Provider pinning, backend
├── parse_dump.py                      # Regenerates locals from a query export
└── modules/
    └── decomposed-alert-family/
        ├── main.tf                    # The alert generation logic
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

## Prerequisites

  - Terraform >= 1.6
  - `coralogix/coralogix` provider 3.1+ available via Terraform Registry
  - Coralogix API key and domain. Supply via env vars before running:
    ```
    export CORALOGIX_API_KEY=<key>
    export CORALOGIX_DOMAIN=<domain>
    ```

## Quick start

```
terraform init
terraform plan
```

`terraform plan` works without API credentials and is the recommended way to inspect the prototype before any apply.

```
terraform apply
```

Applies the 895 resources (894 Alerting + 1 Coverage) to the configured Coralogix tenant.

## Adding a new group

Append an entry to `local.alerts` in `locals_alerts.tf`:

```hcl
{ env = "prod", cluster = "<new-cluster>", namespace = "<new-namespace>" },
```

If the new group needs a non-default threshold:

```hcl
{
  env       = "dev"
  cluster   = "<new-cluster>"
  namespace = "<new-namespace>"
  threshold = 10
}
```

Then `terraform apply`. The Coverage alert will stop firing for that group within 30 minutes.

## Regenerating the full list

When permutations in the tenant change materially (new clusters provisioned, environments renamed, etc), regenerate the locals from a fresh query:

1. Run this PromQL against the eToro Coralogix tenant:
   ```promql
   count(k8s_container_status_reason__container_{
     k8s_container_status_reason = "ImagePullBackOff"
   }) by (deployment_environment_name, k8s_cluster_name, k8s_namespace_name)
   ```
2. Export the result as a JSON dump of label sets, one per line.
3. Pipe through `parse_dump.py`:
   ```
   cat query_result.json | python3 parse_dump.py > new_alerts.hcl
   ```
4. Replace the contents of `local.alerts` in `locals_alerts.tf` with the output.
5. `terraform plan` to see the diff. `terraform apply` to commit.

## What this directory deliberately does NOT do

  - **No Notification Center configuration.** That lives in a separate Terraform directory referenced via Notification Center's name-based binding. See https://registry.terraform.io/providers/coralogix/coralogix/latest/docs/guides/notification-center.
  - **No dashboard.** The Coverage and Spillage dashboard is maintained separately in the Coralogix UI; the Alert IAC POC dashboard already exists.
  - **No alert deletion of the existing 14,630-series alert.** The pre-decomposition alert remains in place during rollout. Delete it as a separate step once the Coverage alert has stabilized at zero for the family.

## Rollback

Two paths:

  - **Per-entry rollback.** Remove the offending entry from `local.alerts` and `terraform apply`. The specific Alerting alert is destroyed; the rest are untouched.
  - **Full rollback.** `terraform destroy` removes all 895 resources cleanly. The pre-decomposition alert (still in the tenant) reverts to being the primary watcher.
