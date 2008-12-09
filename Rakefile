# -*- ruby -*-

# load all optional developer libraries
begin
  require 'rubygems'
  require 'rake/gempackagetask'
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

begin
  require 'dcov'
rescue LoadError
end

begin
  require 'webgen/webgentask'
  require 'webgen/page'
rescue LoadError
end

require 'fileutils'
require 'rake/clean'
require 'rake/testtask'
require 'rake/packagetask'
require 'rake/rdoctask'

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

desc "Generate the HTML documentation"
Webgen::WebgenTask.new('htmldoc') do |site|
  site.clobber_outdir = true
  site.config_block = lambda do |config|
    config['sources'] = [['/', "Webgen::Source::FileSystem", 'doc'],
                         ['/', "Webgen::Source::FileSystem", 'misc', 'default.*'],
                         ['/', "Webgen::Source::FileSystem", 'misc', 'htmldoc.*'],
                         ['/', "Webgen::Source::FileSystem", 'misc', 'images/**/*']]
    config['output'] = ['Webgen::Output::FileSystem', 'htmldoc']
    config.default_processing_pipeline('Page' => 'erb,tags,kramdown,blocks,fragments')
    config['contentprocessor.map']['kramdown'] = 'Kramdown::KDConverter'
  end
end

rd = Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'htmldoc/rdoc'
  rdoc.title = 'Kramdown'
  rdoc.main = 'Kramdown'
  rdoc.options << '--line-numbers' << '--inline-source' << '--promiscuous'
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Build the whole user documentation"
task :doc => [:rdoc, :htmldoc]

tt = Rake::TestTask.new do |test|
  test.libs << 'test'
end

# Release tasks and development tasks ############################################

namespace :dev do

  SUMMARY = 'Kramdown is a fast pure-Ruby Markdown converter.'
  DESCRIPTION = <<EOF
Kramdown is yet-another-markdown-parser but fast, pure Ruby,
using a strict syntax definition and supporting several common extensions.
EOF

  begin
    REL_PAGE = Webgen::Page.from_data(File.read('website/src/news/release_' + Kramdown::VERSION.split('.').join('_') + '.page'))
  rescue
    puts 'NO RELEASE NOTES/CHANGES FILE'
  end

  PKG_FILES = FileList.new([
                            'Rakefile',
                            'setup.rb',
                            'COPYING',
                            'GPL',
                            'VERSION',
                            'ChangeLog',
                            'bin/*',
                            'lib/**/*.rb',
                            'doc/**',
                            'misc/**',
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

      s.add_development_dependency('webgen', '~> 0.5.6')

      s.require_path = 'lib'

      s.executables = ['kramdown']
      s.default_executable = 'kramdown'

      #### Documentation

      s.has_rdoc = true
      s.rdoc_options = ['--line-numbers', '--inline-source', '--promiscuous', '--main', 'Kramdown']

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

    desc 'Generate gemspec file for github'
    task :gemspec do
      spec.version = Kramdown::VERSION + '.' + Time.now.strftime('%Y%m%d')
      spec.summary = 'Kramdown beta build, not supported!!!'
      spec.files = spec.files.reject {|f| f == 'VERSION' || f == 'ChangeLog'}
      spec.post_install_message = "


WARNING: This is an unsupported BETA version of Kramdown which may
still contain bugs!

The official version is called 'kramdown' and can be installed via

    gem install kramdown



"
      File.open('kramdown.gemspec', 'w+') {|f| f.write(spec.to_yaml)}
    end

  end

  desc 'Release Kramdown version ' + Kramdown::VERSION
  task :release => [:clobber, :package, :publish_files]

  desc 'Announce Kramdown version ' + Kramdown::VERSION
  task :announce => [:clobber, :post_news, :website, :publish_website]

  if defined? RubyForge
    desc "Upload the release to Rubyforge"
    task :publish_files => [:package] do
      print 'Uploading files to Rubyforge...'
      $stdout.flush

      rf = RubyForge.new
      rf.configure
      rf.login

      rf.userconfig["release_notes"] = REL_PAGE.blocks['notes'].content
      rf.userconfig["release_changes"] = REL_PAGE.blocks['changes'].content
      rf.userconfig["preformatted"] = false

      files = %w[.gem .tgz .zip].collect {|ext| "pkg/kramdown-#{Kramdown::VERSION}" + ext}

      rf.add_release('kramdown', 'kramdown', Kramdown::VERSION, *files)
      puts 'done'
    end

    desc 'Post announcement to rubyforge.'
    task :post_news do
      print 'Posting announcement to Rubyforge ...'
      $stdout.flush
      rf = RubyForge.new
      rf.configure
      rf.login

      rf.post_news('kramdown', "Kramdown #{Kramdown::VERSION} released", REL_PAGE.blocks['notes'].content)
      puts "done"
    end
  end

  desc 'Generates the webgen website'
  Webgen::WebgenTask.new(:website) do |site|
    site.directory = 'website'
    site.clobber_outdir = true
    site.config_block = lambda do |config|
      config['sources'] += [['/', 'Webgen::Source::FileSystem', '../doc'],
                            ['/', "Webgen::Source::FileSystem", '../misc', 'default.css'],
                            ['/', "Webgen::Source::FileSystem", '../misc', 'htmldoc.*'],
                            ['/', "Webgen::Source::FileSystem", '../misc', 'images/**/*']]
      config.default_processing_pipeline('Page' => 'erb,tags,kramdown,blocks,fragments')
      config['contentprocessor.map']['kramdown'] = 'Kramdown::KDConverter'
    end
  end

  desc "Upload the website to Rubyforge"
  task :publish_website => ['rdoc', :website] do
    sh "rsync -avc --delete --exclude rdoc --exclude 'robots.txt'  website/out/ gettalong@rubyforge.org:/var/www/gforge-projects/kramdown/"
    sh "rsync -avc --delete htmldoc/rdoc/ gettalong@rubyforge.org:/var/www/gforge-projects/kramdown/rdoc"
  end


  if defined? Rcov
    Rcov::RcovTask.new do |rcov|
      rcov.libs << 'test'
    end
  end

  if defined? Dcov
    desc "Analyze documentation coverage"
    task :dcov do
      class Dcov::Analyzer; def generate; end; end
      class NilClass; def file_absolute_name; nil; end; end
      Dcov::Analyzer.new(:path => Dir.getwd, :files => Dir.glob('lib/**'))
    end
  end

  task :benchmark do
    require 'maruku'
    require 'rdiscount'
    require 'bluecloth'
    require 'benchmark'
    text = File.read('doc/syntax.page')
    tms = Benchmark.bm(50) do |b|
      GC.start; GC.start
      b.report('RDiscount') { 10.times { RDiscount.new(text).to_html } }
      GC.start; GC.start
      b.report('BlueCloth') { 10.times { BlueCloth.new(text).to_html } }
      GC.start; GC.start
      b.report('Maruku') { 10.times { Maruku.new(text, :on_error => :ignore).to_html } }
      GC.start; GC.start
      b.report('Kramdown') { 10.times { Kramdown::Document.new(text).to_html } }
    end
  end

end

task :clobber => ['dev:clobber']

# Helper methods and misc  ###################################################################

module Kramdown

  # Processes content in kramdown format using the +maruku+ library.
  class KDConverter

    # Convert the content in +context+ to HTML.
    def call(context)
      require 'kramdown'
      context.content = ::Kramdown::Document.new(context.content).to_html
      context
    end

  end

end
