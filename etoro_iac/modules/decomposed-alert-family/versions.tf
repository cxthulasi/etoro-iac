# Provider requirements for this module are declared in main.tf.
# The coralogix provider is configured by the root module (env = "AP1");
# the API key is supplied at runtime via the CORALOGIX_API_KEY env var
# (injected from Secrets Manager in CI). No credentials belong in this file.
