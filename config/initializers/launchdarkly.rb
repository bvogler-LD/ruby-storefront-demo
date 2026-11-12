# One LaunchDarkly client for the lifetime of the process. Never per request.
#
# The server-side SDK key is read from the environment only. It is never
# logged, rendered, or sent to the browser. With no key (or in the test
# environment) the app runs in fallback mode: see FeatureFlags::NullClient.
require Rails.root.join("lib/feature_flags")

FeatureFlags.client = FeatureFlags.build_client(
  sdk_key: ENV["LAUNCHDARKLY_SDK_KEY"],
  logger: Rails.logger,
  # Tests inject their own recording client and must never reach the network.
  force_null: Rails.env.test?
)

Rails.logger.info("[feature_flags] startup status: #{FeatureFlags.client.status.to_json}")

# Flush pending events and release connections on shutdown.
at_exit { FeatureFlags.client.close }
