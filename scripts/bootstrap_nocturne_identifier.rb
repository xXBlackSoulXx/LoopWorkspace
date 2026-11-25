require "spaceship"
require "net/http"
require "uri"
require "json"

identifier = "com.blacksoul697.nocturnehealth"

token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("FASTLANE_KEY_ID"),
  issuer_id: ENV.fetch("FASTLANE_ISSUER_ID"),
  key: ENV.fetch("FASTLANE_KEY"),
  in_house: false
)

def request(method, path, token, body: nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
  req = klass.new(uri)
  req["Authorization"] = "Bearer #{token.text}"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  [response.code.to_i, response.body]
end

status, body = request(:get, "/v1/bundleIds?filter%5Bidentifier%5D=#{identifier}", token)
abort("Unable to query bundle identifiers (HTTP #{status})") unless status == 200
bundle_id = JSON.parse(body).fetch("data").first

unless bundle_id
  payload = {
    data: {
      type: "bundleIds",
      attributes: {
        name: "Nocturne Health",
        platform: "IOS",
        identifier: identifier
      }
    }
  }
  status, body = request(:post, "/v1/bundleIds", token, body: payload)
  abort("Unable to create bundle identifier (HTTP #{status})") unless status == 201
  bundle_id = JSON.parse(body).fetch("data")
end

bundle_id_value = bundle_id.fetch("id")
status, body = request(:get, "/v1/bundleIds/#{bundle_id_value}/bundleIdCapabilities", token)
abort("Unable to query capabilities (HTTP #{status})") unless status == 200
capabilities = JSON.parse(body).fetch("data")

unless capabilities.any? { |item| item.dig("attributes", "capabilityType") == "HEALTHKIT" }
  payload = {
    data: {
      type: "bundleIdCapabilities",
      attributes: {
        capabilityType: "HEALTHKIT",
        settings: []
      },
      relationships: {
        bundleId: {
          data: { type: "bundleIds", id: bundle_id_value }
        }
      }
    }
  }
  status, _body = request(:post, "/v1/bundleIdCapabilities", token, body: payload)
  abort("Unable to enable HealthKit (HTTP #{status})") unless status == 201
end

status, body = request(:get, "/v1/bundleIds/#{bundle_id_value}/bundleIdCapabilities", token)
verified = status == 200 && JSON.parse(body).fetch("data").any? do |item|
  item.dig("attributes", "capabilityType") == "HEALTHKIT"
end
abort("HealthKit verification failed") unless verified

puts "Verified bundle identifier #{identifier} with HealthKit"
