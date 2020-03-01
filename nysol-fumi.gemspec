#!/usr/bin/env ruby
# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

spec = Gem::Specification.new do |s|
  s.name="nysol-fumi"
  s.version="3.0.0"
  s.author="NYSOL"
  s.email="info@nysol.jp"
  s.homepage="http://www.nysol.jp/"
  s.summary="nysol fumi tools"
	s.files=[
		"lib/nysol/article.rb",
		"lib/nysol/chunk.rb",
		"lib/nysol/dictionary.rb",
		"lib/nysol/knp.rb",
		"lib/nysol/lock.rb",
		"lib/nysol/phrase.rb",
		"lib/nysol/sentence.rb",
		"lib/nysol/tm.rb",
		"lib/nysol/token.rb",
		"lib/nysol/lock.rb",
		"bin/enju_server.rb",
		"bin/menju.rb",
		"bin/mcaseframe.rb",
		"bin/mjuman.rb",
		"bin/mjumandic.rb",
		"bin/mknp.rb",
		"bin/mnewdic.rb"
	]
	s.bindir = 'bin'
	s.executables = [
		"enju_server.rb",
		"menju.rb",
		"mcaseframe.rb",
		"mjuman.rb",
		"mjumandic.rb",
		"mknp.rb",
		"mnewdic.rb"
	]
	s.require_path = "lib"
	s.add_dependency "nysol" ,"~> 3.0.0"
  s.add_development_dependency "bundler", "~> 1.11"
  s.add_development_dependency "rake", ">= 12.3.3"
	s.description = <<-EOF
    nysol FUMI tools
  EOF
end
