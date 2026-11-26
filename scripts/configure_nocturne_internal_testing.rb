require "spaceship"
require "net/http"
require "uri"
require "json"

bundle_identifier = "com.blacksoul697.nocturnehealth"
tester_email = "tom_polenz@icloud.com"
group_name = "Interne Tester"

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
  unless expected.include?(response.code.to_i)
    warn response.body
    abort("App Store Connect request failed: #{method.upcase} #{path} (HTTP #{response.code})")
  end
  response.body.to_s.empty? ? nil : JSON.parse(response.body)
end

app = request(:get, "/v1/apps?filter%5BbundleId%5D=#{bundle_identifier}", token).fetch("data").first
abort("App missing") unless app
app_id = app.fetch("id")
build = request(:get, "/v1/builds?filter%5Bapp%5D=#{app_id}&filter%5BprocessingState%5D=VALID&sort=-uploadedDate&limit=1", token).fetch("data").first
abort("No valid build found") unless build
build_id = build.fetch("id")

groups = request(:get, "/v1/betaGroups?filter%5Bapp%5D=#{app_id}&filter%5BisInternalGroup%5D=true&limit=200", token).fetch("data")
group = groups.find { |item| item.dig("attributes", "name") == group_name }

unless group
  payload = {
    data: {
      type: "betaGroups",
      attributes: {
        name: group_name,
        isInternalGroup: true,
        hasAccessToAllBuilds: true,
        feedbackEnabled: true
      },
      relationships: {
        app: { data: { type: "apps", id: app_id } },
        builds: { data: [{ type: "builds", id: build_id }] }
      }
    }
  }
  group = request(:post, "/v1/betaGroups", token, body: payload, expected: [201]).fetch("data")
end
group_id = group.fetch("id")

# Keep the current valid build explicitly associated even when the group has
# access to all builds, so the first installation is deterministic.
request(
  :post,
  "/v1/betaGroups/#{group_id}/relationships/builds",
  token,
  body: { data: [{ type: "builds", id: build_id }] },
  expected: [204]
)

testers = request(:get, "/v1/betaTesters?filter%5Bemail%5D=#{URI.encode_www_form_component(tester_email)}&limit=10", token).fetch("data")
tester = testers.first

unless tester
  payload = {
    data: {
      type: "betaTesters",
      attributes: {
        email: tester_email,
        firstName: "Tom",
        lastName: "Polenz"
      },
      relationships: {
        betaGroups: { data: [{ type: "betaGroups", id: group_id }] },
        builds: { data: [{ type: "builds", id: build_id }] }
      }
    }
  }
  tester = request(:post, "/v1/betaTesters", token, body: payload, expected: [201]).fetch("data")
else
  request(
    :post,
    "/v1/betaGroups/#{group_id}/relationships/betaTesters",
    token,
    body: { data: [{ type: "betaTesters", id: tester.fetch("id") }] },
    expected: [204]
  )
end

tester_ids = request(:get, "/v1/betaGroups/#{group_id}/relationships/betaTesters", token).fetch("data").map { |item| item.fetch("id") }
build_ids = request(:get, "/v1/betaGroups/#{group_id}/relationships/builds", token).fetch("data").map { |item| item.fetch("id") }
abort("Tester relationship missing") unless tester_ids.include?(tester.fetch("id"))
abort("Build relationship missing") unless build_ids.include?(build_id)

puts JSON.generate({
  group: group_name,
  groupId: group_id,
  tester: tester_email,
  testerId: tester.fetch("id"),
  buildId: build_id,
  buildNumber: build.dig("attributes", "version"),
  processingState: build.dig("attributes", "processingState")
})
