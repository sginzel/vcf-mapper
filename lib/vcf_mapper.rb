class VcfMapper
	@@translator = nil
	def self.split_line_with_header(line, sep = "\t", header = [])
		ret = line.strip.split(sep)
		return nil if ret.size == 0
		if header.size > 0 then
			raise "Header requires at least #{ret.size} elements" if header.size < ret.size
			hsh = {}
			ret = header.each_with_index{|h, i| 
				hsh[h] = ret[i]
			}
			ret = hsh
		end
		return ret
	end
	
	def self.split_line_with_header_csv(line, sep = "\t", header = [])
		if header.size > 0
			CSV.parse_line(line, col_sep: sep, headers: header).to_hash
		else
			CSV.parse_line(line, col_sep: sep).to_a
		end
	end
	
	def self.translate(fun, val, *params)
		begin
			value = val.dup
		rescue TypeError
			value = val
		end
		value = nil if value == "."
		num_args = translator.method(fun.to_sym).arity
		if num_args == 0 then 
			translator.send(fun.to_sym)
		elsif num_args == 1 then
			translator.send(fun.to_sym, value)
		else
			translator.send(fun.to_sym, value, params)
		end
	end
	
	def self.translator()
		if @@translator.nil?  then
			@@translator = VcfMapper::Translator
		end
		@@translator
	end
	
end

require 'vcf_mapper/vcf'
require 'vcf_mapper/profiler'
require 'vcf_mapper/translator'
