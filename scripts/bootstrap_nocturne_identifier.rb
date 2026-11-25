require "spaceship"
require "net/http"
require "uri"

identifier = "com.blacksoul697.nocturnehealth"
healthkit = Spaceship::ConnectAPI::BundleIdCapability::Type::HEALTHKIT

token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("FASTLANE_KEY_ID"),
  issuer_id: ENV.fetch("FASTLANE_ISSUER_ID"),
  key: ENV.fetch("FASTLANE_KEY"),
  in_house: false
)

# Verify that this is a Team key with provisioning access. Individual keys can
# access apps/TestFlight but Apple rejects the bundleIds provisioning endpoint.
def status_for(path, token)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{token.text}"
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }.code.to_i
end

apps_status = status_for("/v1/apps?limit=1", token)
bundle_ids_status = status_for("/v1/bundleIds?limit=1", token)
puts "App Store access status: #{apps_status}"
puts "Provisioning access status: #{bundle_ids_status}"
abort("The existing API key lacks Team provisioning access") unless bundle_ids_status == 200

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
