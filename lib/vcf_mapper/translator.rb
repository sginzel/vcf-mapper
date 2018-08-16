class VcfMapper::Translator
	def self.add(val, params)
		val.to_i + params.flatten.map{|x| x.to_i}.inject(&:+)
	end
	
	def self.substract(val, params)
		val.to_i - params.flatten.map{|x| x.to_i}.inject(&:-)
	end
	
	def self.multiply(val, params)
		val.to_i * params.flatten.map{|x| x.to_i}.inject(&:*)
	end
	
	def self.divide(val, params)
		val.to_i * params.flatten.map{|x| x.to_i}.inject(&:/)
	end
	
	def self.toi(val)
		val.to_i
	end
	
	def self.tof(val)
		val.to_f
	end
	
	def self.toc(val)
		val.to_s
	end
	
	def self.tos(val)
		val.to_s
	end
	
	def self.phred(val)
		-10*Math.log10(val.to_f)
	end
	
	def self.from_phred(val)
		10**(-val.to_f/10)
	end
	
	def self.log(val)
		Math.log(val.to_f)
	end
	
	def self.log2(val)
		Math.log2(val.to_f)
	end
	
	def self.log10(val)
		Math.log10(val.to_f)
	end
	
	def self.round(val, params)
		val.round((params[0][0] || 0).to_i)
	end
	
	def self.ceil(val, params)
		val.round((params[0][0] || 0).to_i)
	end
	
	def self.gsub(val, params)
		val.to_s.gsub(Regexp.new(params[0][0]), params[0][1..-1].join(","))
	end
	
	def self.cat(val, params)
		val.to_s + params.flatten.join("")
	end
	
	def self.upcase(val)
		val.to_s.to_s.upcase
	end
	
	def self.downcase(val)
		val.to_s.downcase
	end
	
	def self.external(val, params)
		params = params.flatten
		cmd = params[0]
		params = params[1..-1].map{|x| (x == "{}")?val:x}
		if params.size > 0 then
			`#{cmd} #{params.flatten.join(" ").gsub("{}", val)}`
		else
			`#{cmd}`
		end
	end
	
	
	
end