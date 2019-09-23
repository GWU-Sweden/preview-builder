require 'sinatra'
require 'json'
require 'octokit'

ACCESS_TOKEN = ENV['GWU_PREVIEW_TOKEN']

before do
	@client ||= Octokit::Client.new(:access_token => ACCESS_TOKEN)
end

post '/event_handler' do
	@payload = JSON.parse(params[:payload])
	puts @payload

	case request.env['HTTP_X_GITHUB_EVENT']
	when "pull_request"
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
		sleep 10
		status_options = status_options.merge({ :description => "Preview build complete", :target_url => "https://some-url.gwu-sweden.org" })
		@client.create_status(pull_request['base']['repo']['full_name'], pull_request['head']['sha'], 'success', status_options)
	end
end
