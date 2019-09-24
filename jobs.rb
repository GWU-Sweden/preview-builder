
require 'resque'

require './github.rb'
require './builder.rb'

if not ENV.has_key?('BUILD_OUTPUT_DIR')
	raise 'Environment variable BUILD_OUTPUT_DIR is not set'
end

Resque.logger.level = Logger::DEBUG

def queue_build(base_repo_name, head_repo_url, head_sha, status_options)
	puts "Queueing build for #{head_repo_url}:#{head_sha}"
	Resque.enqueue(BuildSite, base_repo_name, head_repo_url, head_sha, status_options)
end

class BuildSite
	@queue = :preview

	def self.perform(base_repo_name, head_repo_url, head_sha, status_options)
		puts "#{head_repo_url}:#{head_sha} -- Starting build..."

		Builder.build(head_repo_url, head_sha) do |error, build_output_tmp|
			client = GitHub::setup_client()
			if error != nil
				puts "#{head_repo_url}:#{head_sha} -- Build failed -- #{error}"
				status_options = status_options.merge({ :description => error })
				client.create_status(base_repo_name, head_sha, 'failure', status_options)
				return
			end

			# store build output
			build_output_storage = File.join(ENV['BUILD_OUTPUT_DIR'], head_sha)
			puts "built to #{build_output_tmp}\n\t-> #{build_output_storage}"
			FileUtils.copy_entry(build_output_tmp, build_output_storage)

			status_options = status_options.merge({ :description => "Preview build complete", :target_url => "https://some-url.gwu-sweden.org/#{head_sha}" })
			client.create_status(base_repo_name, head_sha, 'success', status_options)

			puts "#{head_repo_url}:#{head_sha} -- Build done"
			Resque.enqueue(DeploySite, head_repo_url, head_sha, build_output_storage)
		end
	end
end

class DeploySite
	@queue = :preview

	def self.perform(head_repo_url, head_sha, source)
		puts "#{head_repo_url}:#{head_sha} -- Deploying..."
		puts "source to deploy is at #{source}"
		sleep 4
		puts "#{head_repo_url}:#{head_sha} -- Deployed to XYZ"
	end
end
