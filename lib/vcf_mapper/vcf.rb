class VcfMapper::VcfRecord
	
	@line = nil
	
	def map(ffrom, afrom, fto, ato)
		raise "not implemented"
	end
	
	def coords(sep = "\t")
		cols = @line.to_s.strip.split("\t")
		[cols[0], cols[1], cols[3], cols[4]].join(sep)
	end
	
	def parse_str(str)
		return nil if str.nil?
		field, attr = str.split(":", 2)
		if attr.nil? then
			return [field, nil, nil]
		else
			attr1, attridx = attr.scan(/(.*)\[(.*)\]/).flatten
			if attridx.nil? then
				return [field, attr, nil]
			else
				return [field, attr1, attridx]
			end
		end
	end
	
	# return the value of a FROM str
	def get(str)
		field, attr, attridx = parse_str(str)
		{
			field: field,
			attr: attr,
			attridx: attridx,
			value: get_val(field, attr, attridx)
		}
	end
	
	def set(str, val, from = nil)
		field, attr, attridx = parse_str(str)
		from_parsed = parse_str(from)
		{
			field: field,
			attr: attr,
			attridx: attridx,
			value: set_val(field, attr, attridx, val, from_parsed)
		}
	end
	
	def get_val(field, attr, attridx)
		raise "not implemented"
	end
	
	def set_val(field, attr, attridx, val, from = nil)
		raise "not implemented"
	end
	
	def substitute_variables(str)
		return str.map{|s| substitute_variables(s)} if str.is_a?(Array)
		ret = str
		ret = ret.gsub("${LINE}", @line.to_s.strip)
		ret = ret.gsub("${COORDS}", coords(","))
		to_substitute = ret.scan(/\#{.*?}/)
		to_substitute.each do |substr|
			getstr = substr.scan(/{(.*)}/).flatten.first
			get_val = get(getstr)
			val = get_val[:value]
			val = "" if val.nil?
			if val.is_a?(Array) then
				ret = val.map{|v|
					ret.gsub(substr, v.to_s)
				}.join(",")
			else
				# val = val.join(",") if val.is_a?(Array)
				ret = ret.gsub(substr, val.to_s)
			end
		end
		ret
	end
	
	def translate(field, tfrom, tfun, tparam)
		raise "not implemented"
	end
		
	def to_s
		@data.to_s
	end
end

class VcfMapper::VcfMetaRecord < VcfMapper::VcfRecord
	def initialize(meta)
		@data = meta
	end
	
	def get_val(field, attr, attridx)
		if !@data[field].nil? then
			if @data[field].is_a?(Hash) and !@data[field][attr].nil? then
				newmeta = Marshal.load( Marshal.dump(@data) )
			else
				return nil
			end
		else
			return nil
		end
	end
	
	def set_val(field, attr, attridx, val, from = nil)
		
	end
	
	def map(from, to)
		newmeta = get(from)
		return nil if newmeta[:value].nil?
		newmeta = newmeta[:value]
		
		ffrom, afrom, afromidx = parse_str(from)
		fto, ato, atoidx = parse_str(to)
		return VcfMapper::VcfMetaRecord.new(newmeta) if ffrom == fto and afrom == ato and (afromidx.nil? and atoidx.nil?)
		fto = "FORMAT" unless fto == "FILTER" or fto == "INFO" || ffrom == "FORMAT"
		ato = fto if ato.nil? # this happens when other fields without keys are mapped
		newmeta[fto] = {} if newmeta[fto].nil? 
		newmeta[fto][ato] = newmeta[ffrom][afrom]
		newmeta[fto][ato]["ID"] = ato
		if !afromidx.nil? then
			newmeta[fto][ato]["Number"] = "1"
			newmeta[fto][ato]["FROM_INDEX"] = afromidx
		end
		if !atoidx.nil? then
			newmeta[fto][ato]["Number"] = "."
			newmeta[fto][ato]["TO_INDEX"] = atoidx
		end 
		newmeta.delete(ffrom) if ffrom != fto
		newmeta[fto].delete(afrom) if ffrom != fto
		return VcfMapper::VcfMetaRecord.new(newmeta)
	end
	
	# meta records will not be changed on translation
	def translate(field, tfrom, tfun, tparam)
		return nil
	end
	
	def to_vcf
		line = ["##"]
		@data.each do |k,v|
			if !v.is_a?(Hash) then
				line << "#{k}=#{v}"
			else
				line << "#{k}=<#{v.values.map{|hsh| hsh.map{|k1,v1|"#{k1}=#{v1}"}}.join(",")}>"
			end
		end
		line.join("") + "\n"
	end
end

class VcfMapper::VcfHeaderRecord < VcfMapper::VcfRecord
	def initialize(header)
		@data = header
	end
	
	def map(from, to)
	end
	
	# headers need not to be changed during translation
	def translate(field, tfrom, tfun, tparam)
		nil
	end
	
	def [](idx)
		@data[idx]
	end
	
	def []=(idx, val)
		@data[idx] = val
	end
	
	def to_vcf
		"##{@data.join("\t")}" + "\n"
	end
end

class VcfMapper::VcfDataRecord < VcfMapper::VcfRecord
	def initialize(line, meta, header, opts)
		@opts = opts.merge!({
			strict: true
		})
		# @data = CSV.parse_line(line, col_sep: "\t", headers: header).to_hash
		@line = line
		@meta = meta
		@data = VcfMapper.split_line_with_header(line, "\t", header)
		
		@rankby = [@data["CHROM"], @data["POS"]]
		
		@available_fields = Hash[@data.keys.map{|k| [k,true]}]
		@available_fields.default = false
		
		@data["POS"] = @data["POS"].to_i
		
		@snames = (header[9..-1] || [])
		@genotype = Hash[@snames.map{|sname| [sname, {}]}]
		
		## parse FILTER and INFO fields
		infos = Hash[meta["INFO"].keys.map{|k|
			if meta["INFO"][k]["Type"].to_s == "Flag" then
				[k, false]
			else
				[k, nil]
			end
			
		}]
		if @data["INFO"] != "." then
			# vcfinfos = Hash[CSV.parse_line(@data["INFO"].to_s, col_sep: ";").to_a.map{|kv| kv.split("=")}]
			vcfinfos = Hash[VcfMapper.split_line_with_header(@data["INFO"].to_s, ";").map{|kv| kv.split("=", 2)}]
			vcfinfos.keys.each do |k|
				vcfinfos[k] = true if meta["INFO"][k]["Type"].to_s == "Flag"
			end
			infos = infos.merge(vcfinfos)
		end
		
		@data["INFO"] = infos
		
		## parse samples
		if header.size >= 9 then
			formatcols = @data["FORMAT"].to_s.split(":", -1)
			if !formatcols.nil? and formatcols.size > 0 then
				@snames.each do |sname|
					# gtdata = CSV.parse_line(@data[sname].to_s, col_sep: ":", headers: formatcols)
					gtdata = VcfMapper.split_line_with_header(@data[sname].to_s, ":", formatcols)
					if gtdata.nil? then # if no genotype data is available set everything nil
						gtdata = Hash[formatcols.map{|fname| [fname, nil]}]
					else
						gtdata = gtdata.to_hash
					end
					gtdata.keys.each do |gtk|
						if meta["FORMAT"][gtk].nil? then
							if @opts[:strict] then
								raise "Format value (#{gtk}) not definded in meta fields"
							end
							meta["FORMAT"][gtk] = {"Type" => ".", "Number" => "."}
						end
						gtdata[gtk] = gtdata[gtk].to_s.split(",",-1) # split every field by default
						gtdata[gtk].map!{|val|
							if !(val.nil? or val.to_s == ".") then
								val = val.to_i if meta["FORMAT"][gtk]["Type"] == "Integer"
								val = val.to_f if meta["FORMAT"][gtk]["Type"] == "Float"
							end
							val
						}
						gtdata[gtk] = gtdata[gtk][0] if meta["FORMAT"][gtk]["Number"] == "1"
						# gtdata[gtk] = Hash[@data["REF"].split(",").each_with_index.map{|ref, i| [ref, gtdata[gtk][i]]}] if meta["FORMAT"][gtk]["Number"] == "R"
						# gtdata[gtk] = Hash[@data["ALT"].split(",").each_with_index.map{|ref, i| [ref, gtdata[gtk][i]]}] if meta["FORMAT"][gtk]["Number"] == "A"
						# gtdata[gtk] = Hash[gtdata["GT"].to_s.split(",").each_with_index.map{|ref, i| [ref, gtdata[gtk][i]]}] if meta["FORMAT"][gtk]["Number"] == "G"
					end
					@genotype[sname] = gtdata
					@data[sname] = @genotype[sname]
				end
			end
		end
	end
	
	def get_val(field, attr, attridx)
		ret = nil
		if field != "FORMAT" and !@snames.include?(field) then
			if !@data[field].nil? then
				if @data[field].is_a?(Hash) then
					if !@data[field][attr].nil? then
						if !attridx.nil? then
							ret = @data[field][attr][attridx]
						else
							ret = @data[field][attr]
							if !@meta[field].nil? and !@meta[field][attr].nil? then
								if @meta[field][attr]["Type"] == "Flag" then
									if ret then # if the flag is true then set the return value to flags name
										ret = true
									else # if it is false then set it to nil so no changes happen
										ret = false
									end 
								end
							end
						end
					else
						ret = @data[field]
					end
				else
					return @data[field]
				end
			else
				return nil
			end
		else ## handle format
			ret = @snames.map{|sname|
				x = nil
				if field == "FORMAT" || @snames.include?(field) then
					x = @genotype[sname][attr]
					if !x.nil? and !attridx.nil? then
						x = x[attridx.to_i]
					end
				end
				x
			}
			ret = ret[@snames.index(field)] if field != "FORMAT"
		end
		ret
	end
	
	def set_val(field, attr, attridx, val, from)
		if field != "FORMAT" and !@snames.include?(field) then # format needs special processing
			if !@data[field].nil? then
				if @data[field].is_a?(Hash) then
					if attridx.nil? then
						@data[field][attr] = val
					else
						if !@data[field][attr].is_a?(Array) then # field has to be initialized
							@data[field][attr] = [nil]*(attridx.to_i+1)
						end
						@data[field][attr][attridx.to_i] = val
					end
				else
					ffrom, afrom, afromidx = from
					if field != "FILTER"
						# check if the value is a FLAG field (which is true or false)
						if val.is_a?(TrueClass) or val.is_a?(FalseClass) then
							@data[field] = afrom if val
						else
							@data[field] = val
						end
					else
						if !val.nil? then
							if @data[field].to_s == "" or @data[field].to_s == "." then
								if val.is_a?(TrueClass) or val.is_a?(FalseClass) # FLAG
									@data[field] = "#{afrom}" if val
								else
									@data[field] = "#{afrom}_#{val}"
								end
							else
								if val.is_a?(TrueClass) or val.is_a?(FalseClass) # FLAG
									@data[field] = "#{@data[field]};#{afrom}" if val
								else
									@data[field] = "#{@data[field]};#{afrom}_#{val}"
								end
							end
						end
					end
				end
			else
				raise "TO field does not exist."
			end
		else # Set format
			# setup FORMAT column
			if !@data["FORMAT"].index(attr) then
				if @data["FORMAT"].to_s == "" or @data["FORMAT"].to_s == "." then
					@data["FORMAT"] = "#{attr}"
				else
					@data["FORMAT"] = "#{@data["FORMAT"]}:#{attr}"
				end
			end
			@snames.each_with_index.each do |sname, smplidx|
				# initialize field unless it exists
				if attridx.nil? then
					@genotype[sname][attr] = "." if @genotype[sname][attr].nil?
				else
					@genotype[sname][attr] = ["."] * (attridx.to_i+1) if @genotype[sname][attr].nil?
					@genotype[sname][attr] = @genotype[sname][attr].to_s.split(",") unless @genotype[sname][attr].is_a?(Array)
				end
				if field == "FORMAT" or field == sname then
					if attridx.nil? then
						@genotype[sname][attr] = val[smplidx] if val.is_a?(Array)
						@genotype[sname][attr] = val          if !val.is_a?(Array)
					else
						@genotype[sname][attr] = @genotype[sname][attr].split(",") unless @genotype[sname][attr].is_a?(Array)
						@genotype[sname][attr][attridx.to_i] = val[smplidx] if val.is_a?(Array)
						@genotype[sname][attr][attridx.to_i] = val          if !val.is_a?(Array)
					end
				end
			end
		end
	end
	
	def map(from, to)
		val = get(from)
		return self if val.nil?
		if !val[:value].nil? then
			set(to, val[:value], from)
		end
		self
	end
	
	def translate(fieldstr, tfun, tparams)
		val = get(fieldstr)
		field = val[:field]
		attr = val[:attr]
		attridx = val[:attridx]
		current_val = val[:value]
		params = tparams.map{|tparam|
			substitute_variables(tparam).split(",", -1)
		}.flatten
		params = params[0] if !params.nil? and params.is_a?(Array) and params.size == 1
		if field == "FORMAT" or @snames.include?(field) then
			@snames.map.each_with_index do |sname, sidx|
				if field == "FORMAT" or field == sname then
					if current_val.is_a?(Array) then
						if params.is_a?(Array) then
							new_val = VcfMapper.translate(tfun, current_val[sidx], params[sidx])
						else
							new_val = VcfMapper.translate(tfun, current_val[sidx], params)
						end
					else
						if params.is_a?(Array) then
							new_val = VcfMapper.translate(tfun, current_val, params[sidx])
						else
							new_val = VcfMapper.translate(tfun, current_val, params)
						end
					end
					if attridx.nil? then
						set("#{sname}:#{attr}", new_val)
					else
						set("#{sname}:#{attr}[#{attridx}]", new_val)
					end
				end
			end
		elsif @data[field].is_a?(Hash) then
			if !@data[field][tfrom].nil? then
				@data[field][tfrom] = VcfMapper.translate(tfun, @data[field][tfrom], params)
			end
		else
			@data[field] = VcfMapper.translate(tfun, @data[field], params)
		end
	end
	
	def translate_old(field, tfrom, tfun, tparam)
		if field == "FORMAT" then
			@genotype.each do |sname, gtdata|
				if !gtdata[tfrom].is_a?(Array) then
					gtdata[tfrom] = VcfMapper.translate(tfun, gtdata[tfrom], tparam)
				else
					gtdata[tfrom].map!{|x| VcfMapper.translate(tfun, x, tparam)}
				end 
			end
		elsif @data[field].is_a?(Hash) then
			if !@data[field][tfrom].nil? then
				@data[field][tfrom] = VcfMapper.translate(tfun, @data[field][tfrom], tparam)
			end
		else
			@data[field] = VcfMapper.translate(tfun, @data[field], tparam)
		end
	end
	
	def sample_names
		@snames
	end
	
	def has_samples?
		@snames.size > 0
	end
	
	def samples()
		@snames.map do |sname|
			@data[sname]
		end
	end
	
	def sample(sname)
		sname = @snames[sname] if sname.class == "Fixnum"
		@genotype[sname]
	end
	
	def to_s
		"<VCFRecord>" + @data.to_s + "</VCFRecord>"
	end
	
	def to_vcf
		line = []
		@data.map{|k,v|
			if !v.is_a?(Hash) then
				line << v
			else
				if k == "INFO" then
					info_entry = v.reject{|k,v| v.nil? || v == false}.map{|k,v| (v==true)?k:("#{k}=#{v}")}
					info_entry = ["."] if info_entry.size == 0
					line << info_entry.join(";")
				elsif @snames.include?(k)
					sample_entry = v.map{|name, val|
						if val.is_a?(Array)
							val.join(",")
						else
							val
						end
					}
					if sample_entry.reject{|x| x.to_s==""}.size > 1 then
						line << sample_entry.join(":")
					else
						line << sample_entry.reject{|x| x.to_s==""}.join(":")
					end
				else # also true for samples
					other_entries = v.reject{|fmt, val| val.nil? || val.size == 0}.map{|fmt, val|
						if val.is_a?(Array)
							val.join(",")
						else
							val
						end
					}
					if other_entries.size > 0 then
						line << other_entries.join(":")
					else
						line << ""
					end
				end
			end
		}
		line.join("\t") + "\n"
	end
	
end

class VcfMapper::Vcf
	
	def initialize(opts)
		@header = []
		@meta = {}
		@opts = opts.merge!({
			strict: true
		})
	end
	
	def parse(line, &block)
		if line[0] == "#" then
			if line[0..1] == "##" then
				meta = parse_meta line
				VcfMapper::VcfMetaRecord.new(meta)
			else
				@header = line[1..-1].strip.split("\t").freeze
				raise "VCF format requires at least 8 fields" if @header.size < 8
				@samples = @header[9..-1]
				VcfMapper::VcfHeaderRecord.new(@header)
			end
		else
			VcfMapper::VcfDataRecord.new(line, @meta, @header, @opts)
			# @vcfparser.parse_line(line)
		end
	end
	
	def map(vcf_record, mfrom, mto)
		return vcf_record if mfrom.to_s == "" or mto.to_s == ""
		mapped_record = vcf_record.map(mfrom, mto)
		if !mapped_record.nil? then
			if vcf_record.is_a?(VcfMapper::VcfMetaRecord) then
				# we need to add the line to the @meta directroy
				meta = parse_meta mapped_record.to_vcf
				mapped_record = VcfMapper::VcfMetaRecord.new(meta)
			end
			return mapped_record
		end
		vcf_record
	end
	
	def translate(vcf_record, tfrom, tfun, tparams)
		return vcf_record if tfrom.to_s == ""
		funs = tfun.split("|", -1)
		params = tparams.to_s.split("|", -1)
		if params.size > 0 then
			raise "Each function in the chain requires at least an empty parameter." if funs.size != params.size and funs.size > 1
		end
		if funs.size > 1 then
			funs.each_with_index do |fun, i|
				translated = translate(vcf_record, tfrom, fun, params[i])
				break if translated.nil?
			end
		else
			# translated = vcf_record.translate(field, tfrom, tfun, tparams.to_s.split(","))
			translated = vcf_record.translate(tfrom, tfun, tparams.to_s.split(","))
		end
		if !translated.nil? then
			return vcf_record
		else
			return translated
		end
	end
	
	def translate_old(vcf_record, tfrom, tfun, tparams)
		return vcf_record if tfrom.to_s == ""
		field, tfrom = tfrom.split(":")
		tfrom = field if tfrom.nil?
		funs = tfun.split("|", -1)
		params = tparams.to_s.split("|", -1)
		if params.size > 0 then
			raise "Each function in the chain requires at least an empty parameter." if funs.size != params.size and funs.size > 1
		end
		if funs.size > 1 then
			funs.each_with_index do |fun, i|
				translated = translate(vcf_record, "#{field}:#{tfrom}", fun, params[i])
				break if translated.nil?
			end
		else
			# translated = vcf_record.translate(field, tfrom, tfun, tparams.to_s.split(","))
			translated = vcf_record.translate(field, tfrom, tfun, tparams.to_s.split(","))
		end
		if !translated.nil? then
			return vcf_record
		else
			return translated
		end
	end
	
	def parse_meta(line)
		meta = {}
		metaline = line[2..-1].strip
		mkey, mvalue = metaline.split("=", 2)
		if mvalue[0] == "<" then
			metainfos = _parse_meta_value(mvalue)
			meta[mkey] = {} if meta[mkey].nil?
			@meta[mkey] = {} if @meta[mkey].nil?
			meta[mkey][metainfos["ID"]] = metainfos
			@meta[mkey][metainfos["ID"]] = metainfos
		else
			meta[mkey] = mvalue
			@meta[mkey] = mvalue
		end
		meta
	end
	
	def _parse_meta_value(mvalue)
		inside_quote = false
		kvpairs = mvalue[1..-2].split(",").reverse.inject([]){|x, i|
			if inside_quote and x.size > 0 then
				x[-1] = "#{i}#{x[-1]}"
			else
				x << i
			end
			if i[-1] == '"' then
				inside_quote = true
			end
			if i.gsub('\"', "").index('="') then
				inside_quote = false
			end
			x
		}.reverse
		Hash[kvpairs.map{|kv| kv.split("=", 2)}]
	end
	
end

