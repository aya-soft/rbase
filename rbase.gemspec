Gem::Specification.new do |s|
  s.name = 'rbase'
  s.version = '0.1.3'
  s.summary = 'Library to create/read/write to XBase databases (*.DBF files)'
  s.files = Dir.glob('**/*').delete_if { |item| item.include?('.svn') }
  s.require_path = 'lib'
  s.authors = 'Maxim Kulkin, Leonardo Augusto Pires'
  s.email = 'maxim.kulkin@gmail.com, leonardo.pires@gmail.com'
  s.homepage = 'http://rbase.rubyforge.com/'
  s.rubyforge_project = 'rbase'
  s.has_rdoc = true

  s.required_ruby_version = '>= 1.8.2'
end