
require 'resque'

require './github.rb'

Resque.logger.level = Logger::DEBUG

def queue_build(base_repo_name, head_repo_url, head_sha, status_options)
	puts "Queueing build for #{head_repo_url}:#{head_sha}"
	Resque.enqueue(BuildSite, base_repo_name, head_repo_url, head_sha, status_options)
end

class BuildSite
	@queue = :preview

	def self.perform(base_repo_name, head_repo_url, head_sha, status_options)
		puts "#{head_repo_url}:#{head_sha} -- Starting build..."

		# simulate some work
		sleep 4

		status_options = status_options.merge({ :description => "Preview build complete", :target_url => "https://some-url.gwu-sweden.org/#{head_sha}" })
		client = GitHub::setup_client()
		client.create_status(base_repo_name, head_sha, 'success', status_options)

		puts "#{head_repo_url}:#{head_sha} -- Build done"

		Resque.enqueue(DeploySite, head_repo_url, head_sha)
	end
end

class DeploySite
	@queue = :preview

	def self.perform(head_repo_url, head_sha)
		puts "#{head_repo_url}:#{head_sha} -- Deploying..."
		sleep 4
		puts "#{head_repo_url}:#{head_sha} -- Deployed to XYZ"
	end
end
