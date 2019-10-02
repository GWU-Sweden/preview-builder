
require 'resque'

require './github.rb'
require './builder.rb'

if not ENV.has_key?('BUILD_OUTPUT_DIR')
	raise 'Environment variable BUILD_OUTPUT_DIR is not set'
end
if not ENV.has_key?('DEPLOY_DIR')
	raise 'Environment variable DEPLOY_DIR is not set'
end

Resque.logger.level = Logger::DEBUG

def queue_build(base_repo_name, head_repo_url, head_sha, status_options, pull_request_number)
	puts "Queueing build for #{head_repo_url}:#{head_sha}"
	Resque.enqueue(BuildSite, base_repo_name, head_repo_name, head_repo_url, head_sha, status_options, pull_request_number)
end

class BuildSite
	@queue = :preview

	def self.perform(base_repo_name, head_repo_name, head_repo_url, head_sha, status_options, pull_request_number)
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

			puts "#{head_repo_url}:#{head_sha} -- Build done"
			Resque.enqueue(DeploySite, base_repo_name, head_repo_url, head_sha, build_output_storage, pull_request_number, status_options)
		end
	end
end

class DeploySite
	@queue = :preview

	def self.perform(base_repo_name, head_repo_url, head_sha, source, pull_request_number, status_options)
		client = GitHub::setup_client()
		begin
			puts "#{head_repo_url}:#{head_sha} -- Deploying..."

			deploy_path = File.join(ENV['DEPLOY_DIR'], pull_request_number.to_s)
			FileUtils.remove_dir(deploy_path, :force => true)
			puts "Deploying #{source}\n\t-> #{deploy_path}"
			FileUtils.mv(source, deploy_path)
			puts "#{head_repo_url}:#{head_sha} -- Deployed to #{deploy_path}"

			preview_url = "http://#{pull_request_number}.preview.gwu-sweden.org/?#{head_sha}"
			client.add_comment(base_repo_name, pull_request_number, ":robot: Preview of changes deployed to #{preview_url}")
			status_options = status_options.merge({ :description => "Deployed", :target_url => preview_url })
			client.create_status(base_repo_name, head_sha, 'success', status_options)
		rescue StandardError => e
			puts "Deployment failed with error"
			puts e.message
			puts e.backtrace.inspect
			status_options = status_options.merge({ :description => error })
			client.create_status(base_repo_name, head_sha, 'failure', status_options)
		end
	end
end
