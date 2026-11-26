require "spaceship"
require "net/http"
require "uri"
require "json"

bundle_identifier = "com.blacksoul697.nocturnehealth"
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
  abort("App Store Connect query failed (HTTP #{response.code})") unless response.code.to_i == 200
  JSON.parse(response.body)
end

apps = get_json("/v1/apps?filter%5BbundleId%5D=#{bundle_identifier}", token).fetch("data")
abort("App record missing") unless apps.length == 1
app_id = apps.first.fetch("id")
builds = get_json("/v1/builds?filter%5Bapp%5D=#{app_id}&sort=-uploadedDate&limit=10", token).fetch("data")
uploads = get_json("/v1/apps/#{app_id}/buildUploads?limit=20", token).fetch("data")

puts "BUILD_UPLOADS"
uploads.each do |upload|
  attributes = upload.fetch("attributes")
  puts JSON.generate({
    id: upload.fetch("id"),
    cfBundleShortVersionString: attributes["cfBundleShortVersionString"],
    cfBundleVersion: attributes["cfBundleVersion"],
    state: attributes["state"],
    createdDate: attributes["createdDate"],
    uploadedDate: attributes["uploadedDate"],
    platform: attributes["platform"]
  })
end

abort("No builds or build uploads found") if builds.empty? && uploads.empty?
puts "BUILDS"
builds.each do |build|
  attributes = build.fetch("attributes")
  puts JSON.generate({
    id: build.fetch("id"),
    version: attributes["version"],
    processingState: attributes["processingState"],
    uploadedDate: attributes["uploadedDate"],
    expired: attributes["expired"]
  })
end
