
require "jekyll"
require "jekyll/command"
require "jekyll/commands/build"

build = Jekyll::Commands::Build
build.process({
	"source" => "/Users/tobias/Documents/GWU Sweden/Site/gwu-sweden.org",
	"destination" => "build"
})

puts "done"
