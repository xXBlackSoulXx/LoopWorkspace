require "spaceship"
require "net/http"
require "uri"
require "json"

bundle_id = "com.blacksoul697.nocturnehealth"
expected_build = "27"
tester_email = "tom_polenz@icloud.com"

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
  abort("GET #{path} failed: HTTP #{response.code} #{response.body}") unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

app = get_json("/v1/apps?filter%5BbundleId%5D=#{bundle_id}", token).fetch("data").first
abort("Nocturne app not found") unless app
app_id = app.fetch("id")

builds = get_json("/v1/builds?filter%5Bapp%5D=#{app_id}&sort=-uploadedDate&limit=20", token).fetch("data")
build = builds.find { |item| item.dig("attributes", "version") == expected_build }
abort("Build #{expected_build} not found") unless build
state = build.dig("attributes", "processingState")
abort("Build #{expected_build} is #{state}, not VALID") unless state == "VALID"

groups = get_json("/v1/betaGroups?filter%5Bapp%5D=#{app_id}&filter%5BisInternalGroup%5D=true&limit=200", token).fetch("data")
group = groups.find { |item| item.dig("attributes", "name") == "Interne Tester" }
abort("Internal tester group missing") unless group
abort("Internal group lacks all-build access") unless group.dig("attributes", "hasAccessToAllBuilds")

group_tester_ids = get_json("/v1/betaGroups/#{group.fetch("id")}/relationships/betaTesters", token).fetch("data").map { |item| item.fetch("id") }
testers = get_json("/v1/betaTesters?filter%5Bemail%5D=#{URI.encode_www_form_component(tester_email)}&limit=20", token).fetch("data")
assigned = testers.find { |tester| group_tester_ids.include?(tester.fetch("id")) }
abort("#{tester_email} is not assigned to the internal group") unless assigned

puts JSON.generate({
  bundleId: bundle_id,
  version: build.dig("attributes", "preReleaseVersion"),
  buildNumber: expected_build,
  processingState: state,
  uploadedDate: build.dig("attributes", "uploadedDate"),
  group: group.dig("attributes", "name"),
  hasAccessToAllBuilds: group.dig("attributes", "hasAccessToAllBuilds"),
  tester: assigned.dig("attributes", "email")
})
