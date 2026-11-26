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

def get_json(path, token)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP::Get.new(uri)
  request["Authorization"] = "Bearer #{token.text}"
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  abort("HTTP #{response.code}: #{response.body}") unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

bundle_id = "com.blacksoul697.nocturnehealth"
tester_email = "tom_polenz@icloud.com"
app = get_json("/v1/apps?filter%5BbundleId%5D=#{bundle_id}", token).fetch("data").first
abort("App missing") unless app
app_id = app.fetch("id")
build = get_json("/v1/builds?filter%5Bapp%5D=#{app_id}&sort=-uploadedDate&limit=20", token).fetch("data").find { |item| item.dig("attributes", "version") == "32" }
abort("Build 32 missing") unless build
abort("Build 32 state is #{build.dig("attributes", "processingState")}") unless build.dig("attributes", "processingState") == "VALID"

group = get_json("/v1/betaGroups?filter%5Bapp%5D=#{app_id}&filter%5BisInternalGroup%5D=true&limit=200", token).fetch("data").find { |item| item.dig("attributes", "name") == "Interne Tester" }
abort("Internal group missing") unless group&.dig("attributes", "hasAccessToAllBuilds")
ids = get_json("/v1/betaGroups/#{group.fetch("id")}/relationships/betaTesters", token).fetch("data").map { |item| item.fetch("id") }
tester = get_json("/v1/betaTesters?filter%5Bemail%5D=#{URI.encode_www_form_component(tester_email)}&limit=20", token).fetch("data").find { |item| ids.include?(item.fetch("id")) }
abort("Internal tester missing") unless tester
puts JSON.generate({ buildNumber: "32", processingState: "VALID", uploadedDate: build.dig("attributes", "uploadedDate"), group: group.dig("attributes", "name"), hasAccessToAllBuilds: true, tester: tester.dig("attributes", "email") })
