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

uri = URI("https://api.appstoreconnect.apple.com/v1/apps?filter%5BbundleId%5D=#{identifier}")
request = Net::HTTP::Get.new(uri)
request["Authorization"] = "Bearer #{token.text}"
response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
abort("Unable to query App Store Connect (HTTP #{response.code})") unless response.code.to_i == 200
apps = JSON.parse(response.body).fetch("data")
abort("No App Store Connect app found for #{identifier}") unless apps.length == 1
puts "Verified App Store Connect app #{identifier} (ID #{apps.first.fetch("id")})"

key_path = File.join(ENV.fetch("RUNNER_TEMP"), "nocturne-app-store-key.json")
File.write(key_path, JSON.generate({
  key_id: ENV.fetch("FASTLANE_KEY_ID"),
  issuer_id: ENV.fetch("FASTLANE_ISSUER_ID"),
  key: ENV.fetch("FASTLANE_KEY"),
  in_house: false
}))
File.chmod(0o600, key_path)
File.open(ENV.fetch("GITHUB_ENV"), "a") { |file| file.puts("NOCTURNE_API_KEY_PATH=#{key_path}") }
