# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kramdown/version'

Gem::Specification.new do |gem|
  gem.name          = "kramdown"
  gem.version       = Kramdown::VERSION
  gem.authors       = ["Thomas Leitner"]
  gem.email         = ["t_leitner@gmx.at"]
  gem.description   = %q{A free GPL-licensed Ruby library for parsing and converting a superset of Markdown}
  gem.summary       = %q{kramdown is first and foremost a library for converting text written in a superset of Markdown to HTML. However, due to its modular architecture it is able to support additional input and output formats.}
  gem.homepage      = "http://kramdown.rubyforge.org/"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
