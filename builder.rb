
require 'git'
require 'tmpdir'
require "jekyll"
require "jekyll/command"
require "jekyll/commands/build"

module Builder
	def self.build(repo_url, commit_sha)
		begin
			Dir.mktmpdir do |dir|
				puts "Cloning #{repo_url} into #{dir}/clone"
				g = Git.clone(repo_url, "clone", :path => dir)

				puts "Checking out #{commit_sha}"
				g.checkout(commit_sha)

				puts "Building"
				Dir.chdir(dir)
				build = Jekyll::Commands::Build
				build.process({
					"source" => File.join(dir, "clone"),
					"destination" => "build"
				})

				yield(nil, File.join(dir, "build"))
			end
		rescue StandardError => e
			puts e.message
			puts e.backtrace.inspect
			yield(e.message)
		end
	end
end
