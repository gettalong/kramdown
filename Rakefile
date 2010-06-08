# -*- ruby -*-

# load all optional developer libraries
begin
  require 'rubygems'
  require 'rake/gempackagetask'
rescue LoadError
end

begin
  require 'webgen/webgentask'
  require 'webgen/page'
  require 'webgen/website'
rescue LoadError
end

begin
  require 'rdoc/task'
  require 'rdoc/rdoc'
rescue LoadError
end

begin
  require 'rubyforge'
rescue LoadError
end

begin
  require 'rcov/rcovtask'
rescue LoadError
end

require 'fileutils'
require 'rake/clean'
require 'rake/testtask'
require 'rake/packagetask'
require 'erb'

$:.unshift('lib')
require 'kramdown'

# End user tasks ################################################################

task :default => :test

desc "Install using setup.rb"
task :install do
  ruby "setup.rb config"
  ruby "setup.rb setup"
  ruby "setup.rb install"
end

task :clobber do
  ruby "setup.rb clean"
end


if defined? Webgen
  desc "Generate the HTML documentation"
  Webgen::WebgenTask.new('htmldoc') do |site|
    site.clobber_outdir = true
    site.config_block = lambda do |config|
      config['sources'] = [['/', "Webgen::Source::FileSystem", 'doc']]
      config['output'] = ['Webgen::Output::FileSystem', 'htmldoc']
      config.default_processing_pipeline('Page' => 'erb,tags,kramdown,blocks,fragments')
      config.optionsdisplay.items [], :mandatory => 'default'
      config.kdlink.oid nil, :mandatory => true
      config.kdlink.part nil, :mandatory => true
      config['contentprocessor.tags.map']['options'] = 'OptionsDisplay'
      config['contentprocessor.tags.map']['kdexample'] = 'KDExample'
      config['contentprocessor.tags.map']['kdlink'] = 'KDLink'
    end
  end
end

if defined? Rake::RDocTask
  rd = Rake::RDocTask.new do |rdoc|
    rdoc.rdoc_dir = 'htmldoc/rdoc'
    rdoc.title = 'kramdown'
    rdoc.main = 'Kramdown'
    rdoc.options << '--line-numbers'
    rdoc.rdoc_files.include('lib/**/*.rb')
  end
end

if defined?(Webgen) && defined?(Rake::RDocTask)
  desc "Build the whole user documentation"
  task :doc => [:rdoc, 'htmldoc']
end

tt = Rake::TestTask.new do |test|
  test.warning = true
  test.libs << 'test'
end

# Release tasks and development tasks ############################################

namespace :dev do

  SUMMARY = 'kramdown is a fast, pure-Ruby Markdown-superset converter.'
  DESCRIPTION = <<EOF
kramdown is yet-another-markdown-parser but fast, pure Ruby,
using a strict syntax definition and supporting several common extensions.
EOF

  begin
    REL_PAGE = Webgen::Page.from_data(File.read('doc/news/release_' + Kramdown::VERSION.split('.').join('_') + '.page'))
  rescue
    puts 'NO RELEASE NOTES/CHANGES FILE'
  end

  PKG_FILES = FileList.new([
                            'Rakefile',
                            'setup.rb',
                            'COPYING', 'GPL', 'README', 'AUTHORS',
                            'VERSION', 'ChangeLog', 'CONTRIBUTERS',
                            'bin/*',
                            'benchmark/*',
                            'lib/**/*.rb',
                            'man/man1/kramdown.1',
                            'data/**/*',
                            'doc/**',
                            'test/**/*'
                           ])

  CLOBBER << "VERSION"
  file 'VERSION' do
    puts "Generating VERSION file"
    File.open('VERSION', 'w+') {|file| file.write(Kramdown::VERSION + "\n")}
  end

  CLOBBER << 'ChangeLog'
  file 'ChangeLog' do
    puts "Generating ChangeLog file"
    `git log --name-only > ChangeLog`
  end

  CLOBBER << 'CONTRIBUTERS'
  file 'CONTRIBUTERS' do
    puts "Generating CONTRIBUTERS file"
    `echo "  Count Name" > CONTRIBUTERS`
    `echo "======= ====" >> CONTRIBUTERS`
    `git log | grep ^Author: | sed 's/^Author: //' | sort | uniq -c | sort -nr >> CONTRIBUTERS`
  end

  CLOBBER << "man/man1/kramdown.1"
  file 'man/man1/kramdown.1' => ['man/man1/kramdown.1.erb'] do
    puts "Generating kramdown man page"
    File.open('man/man1/kramdown.1', 'w+') do |file|
      file.write(ERB.new(File.read('man/man1/kramdown.1.erb')).result(binding))
    end
  end

  Rake::PackageTask.new('kramdown', Kramdown::VERSION) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = true
    pkg.package_files = PKG_FILES
  end

  if defined? Gem
    spec = Gem::Specification.new do |s|

      #### Basic information
      s.name = 'kramdown'
      s.version = Kramdown::VERSION
      s.summary = SUMMARY
      s.description = DESCRIPTION

      #### Dependencies, requirements and files
      s.files = PKG_FILES.to_a

      s.require_path = 'lib'
      s.executables = ['kramdown']
      s.default_executable = 'kramdown'

      #### Documentation

      s.has_rdoc = true
      s.rdoc_options = ['--line-numbers', '--main', 'Kramdown']

      #### Author and project details

      s.author = 'Thomas Leitner'
      s.email = 't_leitner@gmx.at'
      s.homepage = "http://kramdown.rubyforge.org"
      s.rubyforge_project = 'kramdown'
    end

    Rake::GemPackageTask.new(spec) do |pkg|
      pkg.need_zip = true
      pkg.need_tar = true
    end

  end

  if defined?(RubyForge) && defined?(Webgen) && defined?(Gem) && defined?(Rake::RDocTask)
    desc 'Release Kramdown version ' + Kramdown::VERSION
    task :release => [:clobber, :package, :publish_files, :publish_website, :post_news]
  end

  if defined? RubyForge
    desc "Upload the release to Rubyforge"
    task :publish_files => [:package] do
      print 'Uploading files to Rubyforge...'
      $stdout.flush

      rf = RubyForge.new
      rf.configure
      rf.login

      rf.userconfig["release_notes"] = REL_PAGE.blocks['content'].content
      rf.userconfig["preformatted"] = false

      files = %w[.gem .tgz .zip].collect {|ext| "pkg/kramdown-#{Kramdown::VERSION}" + ext}

      rf.add_release('kramdown', 'kramdown', Kramdown::VERSION, *files)

      sh "gem push pkg/kramdown-#{Kramdown::VERSION}.gem"
      puts 'done'
    end

    desc 'Post announcement to rubyforge.'
    task :post_news do
      print 'Posting announcement to Rubyforge ...'
      $stdout.flush
      rf = RubyForge.new
      rf.configure
      rf.login

      content = REL_PAGE.blocks['content'].content
      content += "\n\n\nAbout kramdown\n\n#{SUMMARY}\n\n#{DESCRIPTION}"
      rf.post_news('kramdown', "kramdown #{Kramdown::VERSION} released", content)
      puts "done"
    end
  end

  desc "Upload the website to Rubyforge"
  task :publish_website => ['doc'] do
    sh "rsync -avc --delete --exclude 'wiki' --exclude 'robots.txt'  htmldoc/ gettalong@rubyforge.org:/var/www/gforge-projects/kramdown/"
  end


  if defined? Rcov
    Rcov::RcovTask.new do |rcov|
      rcov.libs << 'test'
    end
  end

  CODING_LINE = "# -*- coding: utf-8 -*-\n"
  COPYRIGHT=<<EOF
#
#--
# Copyright (C) 2009-2010 Thomas Leitner <t_leitner@gmx.at>
#
# This file is part of kramdown.
#
# kramdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++
#
EOF

  desc "Insert/Update copyright notice"
  task :update_copyright do
    inserted = false
    Dir["lib/**/*.rb"].each do |file|
      if !File.read(file).start_with?(CODING_LINE + COPYRIGHT)
        inserted = true
        puts "Updating file #{file}"
        old = File.read(file)
        if !(result = old.gsub!(/\A#{Regexp.escape(CODING_LINE)}#\n#--.*?\n#\+\+\n#\n/m, CODING_LINE + COPYRIGHT))
          old.gsub!(/\A(#{Regexp.escape(CODING_LINE)})?/, CODING_LINE + COPYRIGHT + "\n")
        end
        File.open(file, 'w+') {|f| f.puts(old)}
      end
    end
    puts "Look through the above mentioned files and correct all problems" if inserted
  end

end

task :clobber => ['dev:clobber']

# Helper methods and misc  ###################################################################

if defined? Webgen

  class OptionsDisplay

    include Webgen::Tag::Base

    def call(tag, body, context)
      param('optionsdisplay.items').collect do |opt|
        Kramdown::Options.definitions[opt]
      end.collect do |term|
        lines = term.desc.split(/\n/)
        first = lines.shift
        rest = lines[0..-2].collect {|l| "  " + l}.join("\n")
        "`#{term.name}`\n: #{first}\n#{rest}"
      end.join("\n")
    end

  end

  require 'cgi'

  class KDExample

    include Webgen::Tag::Base

    def call(tag, body, context)
      result = ::Kramdown::Document.new(body, :auto_ids => false).to_html
      before = "<pre class='kdexample-before'>#{body}<code>\n</code></pre>"
      after = "<pre class='kdexample-after-source'>#{CGI::escapeHTML(result)}<code>\n</code></pre>"
      afterhtml = "<div class='kdexample-after-live'>#{result}</div>"
      "<div class='kdexample'>#{before}#{after}#{afterhtml}\n</div><div class='clear'></div>"
    end

  end

  class KDLink

    include Webgen::Tag::Base

    def call(tag, body, context)
      link = "<a href='syntax.html##{param('kdlink.oid')}'>&rarr; Syntax for #{param('kdlink.part')}</a>"
      "<div class='kdsyntaxlink'>#{link}\n</div>"
    end

  end

end
