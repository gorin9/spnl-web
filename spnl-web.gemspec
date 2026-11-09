Gem::Specification.new do |s|
  s.name = 'spnl-web'
  s.version = '0.2.0'
  s.summary = 'Threaded web building blocks for Ruby and Spinel'
  s.authors = ['gorin9']
  s.homepage = 'https://github.com/gorin9/spnl-web'
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1'
  s.files = Dir['lib/**/*.rb', 'web/**/*.rb', 'spnl_*/**/*.rb', 'spnl_*.rb', 'native/*', 'bin/*', 'README.md', 'LICENSE', 'spin.toml', 'spinel-packer']
  s.require_paths = ['.']
  s.executables = []
end
