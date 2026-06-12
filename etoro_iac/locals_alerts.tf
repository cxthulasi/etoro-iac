###############################################################################
# Alert family decomposition: one entry per (env, cluster, namespace) group.
#
# This file is data, not logic. To add a new group: append an entry. To change
# a threshold for a specific group: set the optional threshold field on that
# entry. No other file needs to change.
#
# Threshold semantics:
#   - Omitted  -> uses var.default_threshold (= 2)
#   - Present  -> overrides for that entry only
#
# Regeneration:
#   The full list was generated from this PromQL run on the Coralogix tenant:
#
#     count(k8s_container_status_reason__container_{
#       k8s_container_status_reason = "ImagePullBackOff"
#     }) by (deployment_environment_name, k8s_cluster_name, k8s_namespace_name)
#
#   When permutations change in the tenant, re-run that query, export the
#   result, and use the parse_dump.py script in this repo to regenerate
#   the entries below.
#
# Total entries when fully populated: 894
###############################################################################

locals {
  alerts = [
    # ------------------------------------------------------------------------
    # Stg
    # ------------------------------------------------------------------------
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "castai-agent" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "cloudhiro" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "default" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "envoy-gateway-system" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "ingress-nginx" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "keda" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "kube-system" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "monitoring" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "walletteam" },
    { env = "Stg", cluster = "Stg-Wallet-AKS-n1", namespace = "wiz" },

    # ------------------------------------------------------------------------
    # dev (sample; full list contains ~100 dev entries including ephemeral
    # testenv-pr-* and coakvb-* namespaces from PR test environments)
    # ------------------------------------------------------------------------
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "alongo-2026" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "castai-agent" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "cloudhiro" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "consul" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "coralogix" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "default" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "kube-system" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "monitoring" },
    { env = "dev", cluster = "dev-main-aks-01-we", namespace = "splunk" },


    # Example: threshold override for an ephemeral PR-test namespace.
    # PR-test namespaces routinely produce transient ImagePullBackOff
    # during deploys. Family default of 2 generates noise. 10 catches
    # genuinely stuck environments while ignoring transients.
    {
      env       = "dev"
      cluster   = "dev-main-aks-01-we"
      namespace = "testenv-pr-5019"
      threshold = 10
    },
    {
      env       = "dev"
      cluster   = "dev-main-aks-01-we"
      namespace = "testenv-pr-5080"
      threshold = 10
    },

    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "argocd" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "castai-agent" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "cloudhiro" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "consul" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "coralogix" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "kube-system" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "nginx" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "splunk" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "velero" },
    { env = "dev", cluster = "dev-mgmt-aks-01-we", namespace = "wiz" },

    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "arc-systems" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "castai-agent" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "cloudhiro" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "coralogix" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "kube-system" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "runners" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "splunk" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "velero" },
    { env = "dev", cluster = "dev-runner-aks-01-we", namespace = "wiz" },

    # ------------------------------------------------------------------------
    # int (sample; full list contains entries for Int-Custodian-AKS-n1,
    # Int-Wallet-AKS-n1, int-aks-argo-import-test-we, int-aks-upgrade-test-01-we,
    # int-aks-we01, int-build-aks-we01, int-deptest-aks-01-we, int-money-aks-01-we,
    # int-pci-aks-03-we, int-test-aks-01-we, int-win-dotnet-build-aks-01-we)
    # ------------------------------------------------------------------------
    { env = "int", cluster = "Int-Wallet-AKS-n1", namespace = "castai-agent" },
    { env = "int", cluster = "Int-Wallet-AKS-n1", namespace = "default" },
    { env = "int", cluster = "Int-Wallet-AKS-n1", namespace = "kube-system" },
    { env = "int", cluster = "Int-Wallet-AKS-n1", namespace = "walletteam" },
    { env = "int", cluster = "Int-Wallet-AKS-n1", namespace = "wiz" },

    { env = "int", cluster = "int-aks-we01", namespace = "applications" },
    { env = "int", cluster = "int-aks-we01", namespace = "bankingteam" },
    { env = "int", cluster = "int-aks-we01", namespace = "complianceapps" },
    { env = "int", cluster = "int-aks-we01", namespace = "kube-system" },
    { env = "int", cluster = "int-aks-we01", namespace = "monitoring" },
    { env = "int", cluster = "int-aks-we01", namespace = "tradingteam" },
    { env = "int", cluster = "int-aks-we01", namespace = "wiz" },

    # ------------------------------------------------------------------------
    # prod (sample; full list contains entries for ~30 prod clusters including
    # prod-aks-we31, prod-aks-ne31, prod-aks-trading-*, prod-money-aks-*,
    # prod-wallet-aks-*, prod-custodian-aks-*, prod-marketing-aks-*,
    # prod-staking-*, prod-backtrader-*, prd-aks-apps-we, prd-aks-vertex-we,
    # corp-runner-aks-01-we, pci-aks-03-ne, pci-aks-03-we)
    # ------------------------------------------------------------------------
    { env = "prod", cluster = "prd-aks-apps-we", namespace = "app-routing-system" },
    { env = "prod", cluster = "prd-aks-apps-we", namespace = "argocd" },
    { env = "prod", cluster = "prd-aks-apps-we", namespace = "cert-manager" },
    { env = "prod", cluster = "prd-aks-apps-we", namespace = "kube-system" },
    { env = "prod", cluster = "prd-aks-apps-we", namespace = "monitoring" },

    { env = "prod", cluster = "prod-aks-we31", namespace = "applications" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "bankingteam" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "complianceapps" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "complianceops" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "engagementteam" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "infrateam" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "kube-system" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "mimoglobalteam" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "mimoopsteam" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "monitoring" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "onboardingteam" },
    { env = "prod", cluster = "prod-aks-we31", namespace = "wiz" },

    { env = "prod", cluster = "prod-aks-ne31", namespace = "applications" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "bankingteam" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "complianceapps" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "complianceops" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "engagementteam" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "kube-system" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "monitoring" },
    { env = "prod", cluster = "prod-aks-ne31", namespace = "wiz" },

    { env = "prod", cluster = "prod-wallet-aks-ne1", namespace = "castai-agent" },
    { env = "prod", cluster = "prod-wallet-aks-ne1", namespace = "kube-system" },
    { env = "prod", cluster = "prod-wallet-aks-ne1", namespace = "monitoring" },
    { env = "prod", cluster = "prod-wallet-aks-ne1", namespace = "walletteam" },
    { env = "prod", cluster = "prod-wallet-aks-ne1", namespace = "wiz" },

    # ------------------------------------------------------------------------
    # qa (sample; full list contains entries for qa-aks-we01, qa-services-aks-01-we)
    # ------------------------------------------------------------------------
    { env = "qa", cluster = "qa-aks-we01", namespace = "automation" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "dealingexec" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "dealingops" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "infrateam" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "kube-system" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "monitoring" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "tradingteam" },
    { env = "qa", cluster = "qa-aks-we01", namespace = "wiz" },

    # ------------------------------------------------------------------------
    # stg (sample; full list contains entries for stg-aks-apps-we, stg-aks-vertex-we,
    # stg-aks-we01, stg-custodian-restricted-aks-ne1, stg-marketing-aks-w1,
    # stg-money-aks-01-we, stg-money-restricted-aks-01-we, stg-pci-aks-03-we,
    # stg-staking-monitoring-aks-1-we, stg-staking-private-aks-1-we,
    # stg-staking-public-aks-1-we, Stg-Custodian-AKS-n1)
    #
    # Note the case inconsistency: "Stg-Custodian-AKS-n1" is capitalized
    # while "stg-aks-we01" is lowercase. PromQL label matching is
    # case-sensitive, so these are correctly treated as distinct values.
    # Flag for Nir's team during the rollout review.
    # ------------------------------------------------------------------------
    { env = "stg", cluster = "stg-aks-we01", namespace = "applications" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "bankingteam" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "dealingexec" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "dealingops" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "kube-system" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "monitoring" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "tradingteam" },
    { env = "stg", cluster = "stg-aks-we01", namespace = "wiz" },

    # ========================================================================
    # TRUNCATED FOR README VISIBILITY.
    #
    # The full list contains 894 entries spanning:
    #   - Stg            (10 entries, 1 cluster)
    #   - dev            (~100 entries, 3 clusters)
    #   - int            (~145 entries, 11 clusters)
    #   - prod           (~350 entries, 30 clusters)
    #   - qa             (~45 entries, 2 clusters)
    #   - stg            (~240 entries, 12 clusters)
    #
    # Run parse_dump.py against the exported query result to repopulate.
    # ========================================================================
  ]
}
