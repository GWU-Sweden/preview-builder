require 'sinatra'
require 'json'

require './jobs.rb'
require './github.rb'


before do
	@client = GitHub::setup_client()
end

post '/event_handler' do
	content_type :json
	case request.env['HTTP_X_GITHUB_EVENT']
	when "pull_request"
		@payload = JSON.parse(request.body.read)
		puts @payload
		if @payload["action"] == "opened" or @payload["action"] == "synchronize"
			handle_pull_request_update(@payload["pull_request"])
		end
	end

	"OK"
end

helpers do
	def handle_pull_request_update(pull_request)
		puts "Lets build preview for PR ##{pull_request['number']} \"#{pull_request['title']}\""

		pull_request_number = pull_request['number']
		base_repo_name = pull_request['base']['repo']['full_name']
		head_repo_name = pull_request['head']['repo']['full_name']
		head_repo_url = pull_request['head']['repo']['clone_url']
		head_sha = pull_request['head']['sha']

		status_options = { :context => "Build", :description => "Generating preview build of site" }
		@client.create_status(base_repo_name, head_sha, 'pending', status_options)

		queue_build(base_repo_name, head_repo_name, head_repo_url, head_sha, status_options, pull_request_number)
	end
end
