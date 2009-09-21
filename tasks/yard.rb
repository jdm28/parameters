lib_dir = File.expand_path(File.join(File.dirname(__FILE__),'..','lib'))
unless $LOAD_PATH.include?(lib_dir)
  $LOAD_PATH.unshift(lib_dir)
end

require 'parameters/yard/handlers'

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
  t.options = [
    '--quiet',
    '--protected',
    '--files', 'History.txt',
    '--title', 'Parameters'
  ]
end

task :docs => :yardoc
