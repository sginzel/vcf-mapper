Gem::Specification.new do |s|
	s.name        = 'vcf-mapper'
	s.version     = '0.0.1'
	s.date        = '2015-08-20'
	s.summary     = "A tool to map and transform attributes in a VCF file."
	s.description = "This tool can be used to modifiy files in variant call format."
	s.authors     = ["Sebastian Ginzel"]
	s.email       = 'sginze2s@inf.h-brs.de'
	s.files       = ["Gemfile", "Rakefile", "LICENSE", 
		"lib/vcf_mapper.rb", "lib/vcf_mapper/profiler.rb", "lib/vcf_mapper/translator.rb", "lib/vcf_mapper/vcf.rb", 
		"bin/vcf-mapper"]
	s.homepage    = 'http://rubygems.org/gems/vcf-mapper'
	s.add_runtime_dependency 'trollop', '>=2.1.2'
	s.license     = 'MIT'
	s.executables << 'vcf-mapper'
	s.extra_rdoc_files = [
		"README",
		"doc/user-guide.txt"
	]
	s.rdoc_options << '--title' << 'Rake -- Ruby Make' <<
  '--main' << 'README' <<
  '--line-numbers'
end
