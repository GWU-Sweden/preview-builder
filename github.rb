require 'octokit'
require 'openssl'
require 'jwt'

if not ENV.has_key?('GWU_PREVIEW_INSTALLATION_ID')
	raise 'Environment variable GWU_PREVIEW_INSTALLATION_ID is not set'
end
if not ENV.has_key?('GWU_PREVIEW_PEM')
	raise 'Environment variable GWU_PREVIEW_PEM is not set'
end

APP_ID = 41810
INSTALLATION_ID = ENV['GWU_PREVIEW_INSTALLATION_ID']

module GitHub
	def self.setup_client()
		private_pem = File.read(ENV['GWU_PREVIEW_PEM'])
		private_key = OpenSSL::PKey::RSA.new(private_pem)

		jwt_payload = {
			iat: Time.now.to_i,
			exp: Time.now.to_i + (5 * 60),
			iss: APP_ID
		}
		jwt_token = JWT.encode(jwt_payload, private_key, "RS256")

		# uncomment to enable debug logging
		# stack = Faraday::RackBuilder.new do |builder|
		# 	builder.use Faraday::Request::Retry, exceptions: [Octokit::ServerError]
		# 	builder.use Octokit::Middleware::FollowRedirects
		# 	builder.use Octokit::Response::RaiseError
		# 	builder.use Octokit::Response::FeedParser
		# 	builder.response :logger
		# 	builder.adapter Faraday.default_adapter
		# end
		# Octokit.middleware = stack

		client = Octokit::Client.new(bearer_token: jwt_token)
		resource = client.create_installation_access_token(INSTALLATION_ID, accept: 'application/vnd.github.machine-man-preview+json').to_h
		client.access_token = resource.fetch(:token)
		return client
	end
end
