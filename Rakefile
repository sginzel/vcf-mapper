# require "rake"

desc "Process a single BAM with standard parameters..."
task :hello, [:bam, :coords] do
	paramstr = YAML.load_file("./ramplicon.yaml").map{|k,v|
		if v.is_a?(String) 
			"--#{k} \"#{v}\""
		else
			"--#{k} #{v}"
		end
	}.join(" ")
	system("./ramplicon --bam #{args[:bam]} --coords #{args[:coords]} #{paramstr}")
end