require "spaceship"

identifier = "com.blacksoul697.nocturnehealth"
healthkit = Spaceship::ConnectAPI::BundleIdCapability::Type::HEALTHKIT

token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("FASTLANE_KEY_ID"),
  issuer_id: ENV.fetch("FASTLANE_ISSUER_ID"),
  key: ENV.fetch("FASTLANE_KEY"),
  in_house: false
)
Spaceship::ConnectAPI.token = token

bundle_id = Spaceship::ConnectAPI::BundleId.find(identifier)
bundle_id ||= Spaceship::ConnectAPI::BundleId.create(
  name: "Nocturne Health",
  platform: "IOS",
  identifier: identifier
)

bundle_id.update_capability(healthkit, enabled: true)
capabilities = bundle_id.get_capabilities
unless capabilities.any? { |capability| capability.is_type?(healthkit) }
  abort("HealthKit capability was not enabled")
end

puts "Verified bundle identifier #{bundle_id.identifier} with HealthKit"
