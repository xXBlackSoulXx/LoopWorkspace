require "spaceship"
require "net/http"
require "uri"
require "json"

token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("FASTLANE_KEY_ID"),
  issuer_id: ENV.fetch("FASTLANE_ISSUER_ID"),
  key: ENV.fetch("FASTLANE_KEY"),
  in_house: false
)

def request(method, path, token, body: nil, expected: [200])
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token.text}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  abort("HTTP #{response.code}: #{response.body}") unless expected.include?(response.code.to_i)
  response.body.to_s.empty? ? nil : JSON.parse(response.body)
end

identifier = "com.blacksoul697.nocturnehealth"
bundle = request(:get, "/v1/bundleIds?filter%5Bidentifier%5D=#{identifier}", token).fetch("data").first
abort("Bundle ID missing") unless bundle
bundle_id = bundle.fetch("id")
capabilities = request(:get, "/v1/bundleIds/#{bundle_id}/bundleIdCapabilities?limit=200", token).fetch("data")
unless capabilities.any? { |item| item.dig("attributes", "capabilityType") == "ASSOCIATED_DOMAINS" }
  request(
    :post,
    "/v1/bundleIdCapabilities",
    token,
    body: {
      data: {
        type: "bundleIdCapabilities",
        attributes: { capabilityType: "ASSOCIATED_DOMAINS" },
        relationships: { bundleId: { data: { type: "bundleIds", id: bundle_id } } }
      }
    },
    expected: [201]
  )
end
verified = request(:get, "/v1/bundleIds/#{bundle_id}/bundleIdCapabilities?limit=200", token).fetch("data")
abort("Associated Domains capability not enabled") unless verified.any? { |item| item.dig("attributes", "capabilityType") == "ASSOCIATED_DOMAINS" }
puts JSON.generate({ identifier: identifier, associatedDomains: true })
