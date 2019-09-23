require 'sinatra'
require 'json'
require 'octokit'
require 'openssl'
require 'jwt'

APP_ID = 41810
INSTALLATION_ID = ENV['GWU_PREVIEW_INSTALLATION_ID']

before do
	puts "Setting up Octokit client..."

	private_pem = File.read(ENV['GWU_PREVIEW_PEM'])
	private_key = OpenSSL::PKey::RSA.new(private_pem)

	jwt_payload = {
		iat: Time.now.to_i,
		exp: Time.now.to_i + (5 * 60),
		iss: APP_ID
	}
	jwt_token = JWT.encode(jwt_payload, private_key, "RS256")
	puts jwt_token

	# uncomment to enable debug logging
	stack = Faraday::RackBuilder.new do |builder|
		builder.use Faraday::Request::Retry, exceptions: [Octokit::ServerError]
		builder.use Octokit::Middleware::FollowRedirects
		builder.use Octokit::Response::RaiseError
		builder.use Octokit::Response::FeedParser
		builder.response :logger
		builder.adapter Faraday.default_adapter
	end
	Octokit.middleware = stack

	@client = Octokit::Client.new(bearer_token: jwt_token)
	puts "  creating installation token"
	resource = @client.create_installation_access_token(INSTALLATION_ID, accept: 'application/vnd.github.machine-man-preview+json').to_h
	puts "  configuring with access_token #{resource.fetch(:token)}"
	@client.access_token = resource.fetch(:token)
end

post '/event_handler' do
	content_type :json
	case request.env['HTTP_X_GITHUB_EVENT']
	when "pull_request"
		@payload = JSON.parse(request.body.read)
		puts @payload
		if @payload["action"] == "opened" or @payload["action"] == "synchronize"
			build_pull_request(@payload["pull_request"])
		end
	end

	"OK"
end

helpers do
	def build_pull_request(pull_request)
		puts "Lets build preview for PR ##{pull_request['number']} \"#{pull_request['title']}\""

		status_options = { :context => "Build", :description => "Generating preview build of site" }
		@client.create_status(pull_request['base']['repo']['full_name'], pull_request['head']['sha'], 'pending', status_options)

		# simulate some work
		sleep 10

		status_options = status_options.merge({ :description => "Preview build complete", :target_url => "https://some-url.gwu-sweden.org" })
		@client.create_status(pull_request['base']['repo']['full_name'], pull_request['head']['sha'], 'success', status_options)
	end
end
