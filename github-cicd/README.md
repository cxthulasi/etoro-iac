# etoro-iac CI/CD (GitHub Actions)

A GitHub-native CI/CD pipeline that deploys the `etoro_iac` Coralogix Terraform
project. It is the functional equivalent of the AWS CodePipeline in `[../cicd](../cicd)`:
it runs **plan + lint**, waits for a **manual approval**, then **applies** to
Coralogix.

## Pipeline flow

```
push to main / workflow_dispatch
        │
        ▼
[ plan ]      Plan & Lint job
              terraform fmt -check · tflint · terraform validate · terraform plan -out=tfplan
              └─ uploads tfplan as a workflow artifact
        │
        ▼
[ approval ]  GitHub Environment "production" with required reviewers
              └─ reviewers get an email/notification and must approve
        │
        ▼
[ apply ]     Apply job
              terraform apply tfplan  →  Coralogix
```

Pull requests run the **plan** job only (no artifact, no apply), giving reviewers
a plan preview on the PR without any chance of deploying.

## AWS CodePipeline → GitHub Actions mapping


| AWS stack (`../cicd`)                                  | GitHub Actions (here)                                |
| ------------------------------------------------------ | ---------------------------------------------------- |
| CodeCommit repo `etoro-iac` + EventBridge push trigger | `on: push` to `main`                                 |
| CodeBuild **plan** project + `plan.yml` buildspec      | `plan` job                                           |
| CodePipeline **manual approval** + SNS email           | **Environment `production`** with required reviewers |
| CodeBuild **apply** project + `apply.yml` buildspec    | `apply` job                                          |
| Secrets Manager (`etoro-iac/coralogix`)                | GitHub **secret** `CORALOGIX_API_KEY`                |
| CodeBuild IAM role (S3 state access)                   | **OIDC role** assumed via `AWS_ROLE_ARN`             |
| Pipeline artifact bucket (plan hand-off)               | `actions/upload-artifact` → `download-artifact`      |


The remote state is unchanged: both pipelines use the **same S3 backend** with
native lockfiles (`use_lockfile=true`), so you can run either pipeline against the
same state.

## Activate the workflow

GitHub only executes workflows located in `.github/workflows/`. This folder holds
the source of truth; copy the file to activate it:

```bash
mkdir -p .github/workflows
cp github-cicd/workflows/etoro-iac.yml .github/workflows/etoro-iac.yml
git add .github/workflows/etoro-iac.yml
git commit -m "ci: add etoro-iac GitHub Actions pipeline"
git push
```

## One-time setup

### 1. AWS access for the S3 backend (OIDC — recommended)

The jobs need AWS credentials to read/write the Terraform state in S3. The
recommended approach is GitHub OIDC (no long-lived keys):

1. Create an IAM **OIDC identity provider** for `token.actions.githubusercontent.com`.
2. Create an IAM role trusted by your repo (condition on `repo:<org>/<repo>:`*)
  with permissions to the state bucket (and object lock) — equivalent to the
   `TerraformState` statements in `../cicd/iam.tf`.
3. Add the role ARN as the repo secret `AWS_ROLE_ARN`.

Alternative: static access keys (not recommended)

Replace the `Configure AWS credentials (OIDC)` steps with:

```yaml
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
```

and remove `id-token: write` from `permissions`.



### 2. Secrets and variables

In **Settings → Secrets and variables → Actions**:


| Kind     | Name                | Value                                                                             |
| -------- | ------------------- | --------------------------------------------------------------------------------- |
| Secret   | `CORALOGIX_API_KEY` | Coralogix API key (`cxup_...`)                                                    |
| Secret   | `AWS_ROLE_ARN`      | IAM role ARN for OIDC                                                             |
| Variable | `TF_STATE_BUCKET`   | S3 bucket holding `etoro_iac` state (e.g. `etoro-iac-tfstate-<region>-<account>`) |


The state **key**, **region**, Terraform/TFLint **versions**, and **working dir**
are set as `env:` defaults at the top of the workflow — adjust there if needed.

### 3. The approval gate (Environment)

In **Settings → Environments**:

1. Create an environment named `**production`**.
2. Enable **Required reviewers** and add the approver(s).
3. (Optional) Restrict deployment branches to `main`.

When the `apply` job is reached, the reviewers receive a notification and the job
pauses until one of them approves in the **Actions** run page — the direct
equivalent of the SNS email approval in the AWS stack.

## How it stays consistent with the AWS pipeline

- Same Terraform commands and flags (`-input=false`, `-lock-timeout=120s`,
`-out=tfplan`, `-auto-approve tfplan`).
- Same backend config (`bucket`, `key`, `region`, `use_lockfile`, `encrypt`).
- Same provider credential model: only `CORALOGIX_API_KEY` is injected;
`CORALOGIX_DOMAIN` is intentionally **not** set because the provider's
`env = "AP1"` (in `etoro_iac/versions.tf`) conflicts with `domain`.
- The plan is produced once and applied as-is after approval, so what you approve
is exactly what gets deployed.

## Notes

- Commit `etoro_iac/.terraform.lock.hcl` so the apply job resolves the same
provider versions the plan was built with (the workflow also carries the lock
file in the artifact as a safeguard).
- If a run fails with **"Saved plan is stale"**, the remote state changed between
plan and apply (e.g. a partial earlier apply). Re-run the workflow to generate a
fresh plan, then approve that one.
- `AWS_REGION` here refers to where the **state bucket** lives, not the Coralogix
tenant region (which is fixed to AP1 by the provider).

