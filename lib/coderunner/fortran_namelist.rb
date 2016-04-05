class CodeRunner
	
class Run

	# This is a class which is has several methods to facilitate the generation
	# of input files for simulation codes which use a Fortran namelist style 
	# input file.
	#
	# Those developing a code module to deal with such a simulation code can 
	# make their custom run class a subclass of this class, and take advantage
	# of all its functionality.
	#
	# There is a convention introduced by this class:
	#    * a "code_variable" is a variable name as it appears in the simulation code
	#    * a "variable" is a variable name as it appears in and is referred to by CodeRunner 
	# Why is this necessary? Every variable in CodeRunner has to have a 
	# <em>unique,lowercase</em> name. In contrast, in the simulation code, variables
	# in different namelists can have the same name, and this name may contain uppercase
	# letters. To get around this problem, when it occurs, a new CodeRunner name is
	# defined and the name as it appears in the simulation code (which is referred to 
	# as the code_variable), is stored in the database as <tt>:code_name</tt>.   

	class FortranNamelist < Run

	# Read the database of namelists and generate the four run class properties
	#  * variables_with_help
	#  * variables_with_autoscanned_defaults
	#  * variables_with_hashes
	#  * variables
	# 
	# The full namelist database itself is assigned to the run class property
	#   * namelists
	# 
	# (Reminder: run class properties are accessed with the <tt>rcp</tt> call)

	def self.setup_namelists(folder)
	# 		folder = File.dirname(__FILE__)


		namelist_file = folder + '/namelists.rb'
		unless FileTest.exist?(namelist_file)
			File.open(namelist_file, 'w'){|file| file.puts '{}'}
		end
		@namelists = eval(File.read(folder + '/namelists.rb'), binding, folder + '/namelists.rb') 

		@variables_with_help = (@namelists.inject({}) do |hash, (namelist, namelist_hash)|
			namelist_hash[:variables].each{|var, var_hash| hash[var] = var_hash[:help] if var_hash[:help]}
			hash
		end) 

		@variables_with_autoscanned_defaults = (@namelists.inject({}) do |hash, (namelist, namelist_hash)|
			namelist_hash[:variables].each{|var, var_hash| hash[var] = var_hash[:autoscanned_defaults] if var_hash[:autoscanned_defaults]}
			hash
		end)

		@variables_with_hashes = @namelists.inject({}) do |hash, (namelist, namelist_hash)|
			namelist_hash[:variables].each{|var, var_hash| hash[var] = var_hash unless hash[var] and hash[var][:help]} # If there are duplicates, take the one with help
			hash
		end

	@variables = @namelists.inject([]) do |arr, (namelist, namelist_hash)|
		if en = namelist_hash[:enumerator]
			en[:estimated_value].times do |i|
				namelist_hash[:variables].each{|var, var_hash| arr.push var + "_#{i+1}".to_sym}
			end
		else
			namelist_hash[:variables].each{|var, var_hash| arr.push var}
		end
		arr
	end
	
	@variable_names_from_code_names = @variables_with_hashes.inject({}) do |hash, (var, var_hash)|
		hash[(var_hash[:code_name] || var)] = var
	 	hash
	end
		


	# VARIABLES = VARIABLES_WITH_HELP.keys
	@variables.each{|var| attr_accessor var}

	# Needed for backwards compatibility with old simulation data - variables that
	# are no longer input parameters for the current version of the 
	# simulation code.
	#
	

	begin
		@deleted_variables = eval(File.read(folder + '/deleted_variables.rb'), binding, folder + '/deleted_variables.rb')
	rescue Errno::ENOENT
		@deleted_variables = {}
		#save_deleted_variables
	end

	@deleted_variables.keys.each{|var| attr_accessor var}
	

end

	
# Does the variable var exist? If it does exist, returns a list of the namelists
# in which it is found. Otherwise returns false

def self.variable_exists?(namelist=nil, var)
	exists = false
		#exists = rcp.namelists.find_all{|namelist, hash| hash[:variables].keys.map{|v| v.to_s.downcase.to_sym}.include? var.to_s.downcase.to_sym}
		exists = rcp.namelists.find_all{|namelist, hash| hash[:variables].keys.include? var}
# 	end
	return exists.size > 0 ? exists.map{|(namelist, hash)| namelist} : false
end

# Returns true if the code variable (which may correspond to the code name) is present
# in namelist 

def self.known_code_variable?(namelist, var)
	return true if rcp.namelists[namelist.to_s.downcase.to_sym] and rcp.namelists[namelist.to_s.downcase.to_sym][:variables].map{|(v,h)| (h[:code_name] or v).to_s.downcase.to_sym}.include? var.to_s.downcase.to_sym
# 	end
	return false
end

# Deletes the given variable from the namelists and saves the namelists

def self.delete_variable(namelist, var)
	#variables_hash = rcp.namelists[namelist][:variables]
	#var_name = (variables_hash.find do |var_n, var_hash|
		#var_hash[:code_name] == var or var_n == var
	#end)[0]
	rcp.deleted_variables ||= {}
	rcp.deleted_variables[var] = rcp.namelists[namelist][:variables][var]
	rcp.namelists[namelist][:variables].delete(var)

	save_deleted_variables
	save_namelists
end

# This reads the mediawiki documentation of the input variables (as generated 
# by write_mediawiki_documentation), copied from a wiki where it has been posted
# and placed in <tt>file</tt>, to see if anyone has updated the variable help 
# on the wiki.

def self.read_mediawiki_documentation(file = ARGV[2])
	documentation = File.read(file)
	#documentation.scan(/^(?<markup>=+)(?<namelist>\w+)\k<markup>(?<vars>.+?)\s+(?=^\k<markup>|\s*\Z)/m) do
	documentation.sub!(/\A.*=Namelists=/m, '')
	documentation.sub!(/\<\/textarea.*\Z/m, '')
	#documentation.scan(/(?<markup>=+)(?<namelist>\w+)\k<markup>(?<vars>.+?)\s+(?=\k<markup>|\|\})/m) do
	eputs 'Scanning mediawiki markup...'
	documentation.scan(/(?<markup>=+)(?<namelist>\w+)\k<markup>(?<vars>.+?)\s+(?=\|\})/m) do
		p 'nmlist', namelist = $~[:namelist].downcase.to_sym
		vars = $~[:vars]
		p vars
		#vars.scan(/^\*\s*(?:\[\[)?(?<var>\w+)(?:\]\])?\s*:\s+(?<help>.+?)(?=\n\*[^*]|\s*\Z)/m) do
		vars.scan(/\|\-\s+\|'''\[\[(?<altvar>\w+)\]\]'''\s+\|\|.*?\|\|.*?\|\|\s*?
							(?<var>\w+)?
							\s*\|\s*
							\<\!\-\-\s*begin\s+help\s*\-\-\>
													 (?<help>.+?)
													 \<\!\-\-\s*end\s+help\s*\-\-\>
													 /mx) do
		  if $~[:var]
				var = $~[:var].downcase.to_sym
			else
				var = $~[:altvar].downcase.to_sym
			end
			help = $~[:help].sub(/\A\s*\*\s*/, '')
			p var, help
			sync_variable_help(namelist, var, help) if help.length > 0
		end
	end
end

# For backward compatibility: ensures that all variables (NB variables,
# not code_variables) are lower case in the namelist database

def self.correct_namelist_cases
	rcp.namelists.each do |namelist, namelist_hash|
		namelist_hash[:variables].each do |var, varhash|
			#p var
			if var.to_s =~ /[A-Z]/ or var.kind_of? String
				p var
				namelist_hash[:variables].delete(var)
				namelist_hash[:variables][var.to_s.downcase.to_sym] = varhash
			end
		end
	end
	save_namelists
end
		
# Edit the help for the namelist. Requires the environment variable EDITOR to be
# set.

def self.edit_namelist_help(namelist, message = "")
	raise ArgumentError.new("Unknown namelist #{namelist}") unless namelist_hash = rcp.namelists[namelist]
	raise "Please set the environment variable EDITOR" unless ENV['EDITOR']
	File.open('/tmp/.tmp_namelist_help.txt', 'w') do |file|
		file.puts <<EOF

------------------------------------------------------------------
Editing help and description for namelist #{namelist}:
-----------------------------------------------------------------

Edit the help and description, then save and quit the editor. Help can be long and detailed, and can include MediaWiki markup. Description should be short and in plain text.

#{message}

-------------------------------------begin help text


#{namelist_hash[:help]}


------------------------------------begin description

#{namelist_hash[:description]}
EOF
	end
	system "#{ENV['EDITOR']} /tmp/.tmp_namelist_help.txt"
	namelist_hash[:help], namelist_hash[:description] = File.read('/tmp/.tmp_namelist_help.txt').split(/^\-+begin help text/)[1].split(/^\-+begin description/, -1).map{|s| s.sub(/\A\s+/, '').sub(/\s+\Z/, '')}
	save_namelists
end

# Edit the help for the variable in var in the given namelist. 
# Requires the environment variable EDITOR to be set.

def self.edit_variable_help(namelist, var, message = "")
	raise ArgumentError.new("Unknown namelist,variable #{namelist},#{var}") unless namelist_hash = rcp.namelists[namelist] and var_hash = namelist_hash[:variables][var]
	raise "Please set the environment variable EDITOR" unless ENV['EDITOR']
	File.open('/tmp/.tmp_variable_help.txt', 'w') do |file|
		file.puts <<EOF

------------------------------------------------------------------
Editing help and description for #{var} in namelist #{namelist}:
-----------------------------------------------------------------

Edit the help and description, then save and quit the editor. Help can be long and detailed, and can include MediaWiki markup. Description should be short and in plain text.

#{message}

-------------------------------------begin help text


#{var_hash[:help]}


------------------------------------begin description

#{var_hash[:description]}
EOF
	end
	system "#{ENV['EDITOR']} /tmp/.tmp_variable_help.txt"
	var_hash[:help], var_hash[:description] = File.read('/tmp/.tmp_variable_help.txt').split(/^\-+begin help text/)[1].split(/^\-+begin description/, -1).map{|s| s.sub(/\A\s+/, '').sub(/\s+\Z/, '')}
	save_namelists
end

# If variable var in the given namelist has no help, add <tt>help</tt> (a string) to it. 
# If it already has help which is different from <tt>help</tt>, open an editor to allow 
# the user to resolve the conflict. 
# Requires the environment variable EDITOR to be set.

def self.sync_variable_help(namelist, var, help)
	raise ArgumentError.new("Unknown namelist,variable #{namelist.inspect},#{var.inspect}") unless namelist_hash = rcp.namelists[namelist] and var_hash = namelist_hash[:variables][var]
	if not var_hash[:help] or var_hash[:help] == ""
		var_hash[:help] = help
		save_namelists
		return
	elsif var_hash[:help].sub(/\A\s+/, '').sub(/\s+\Z/, '') == help.sub(/\A\s+/, '').sub(/\s+\Z/, '')
		return
	else
		var_hash[:help] = <<EOF

.<<<<<<<<<<<<current

#{var_hash[:help]}

.>>>>>>>>>>>>new

#{help}
EOF
		edit_variable_help(namelist, var, "Note: There has been a conflict.")
	end
end

# Add help to the variable in the given namelist

def self.add_help_to_variable(namelist=ARGV[-3], var=ARGV[-2], help=ARGV[-1])
#   p rcp.namelists[namelist.to_sym]
  rcp.namelists[namelist.to_sym][:variables][var.to_sym][:help] = help
  rcp.namelists[namelist.to_sym][:variables][var.to_sym][:description] ||= help
  save_namelists
end

# Add variable <tt>var</tt>, with a sample value, to <tt>namelist</tt>
# in the database of namelists. 
# The parameter <tt> var</tt> should be the name of the variable as it appears
# in the simulation code.

def self.add_code_variable_to_namelist(namelist, var, value)
	code_name = var.to_s.downcase.to_sym
	var = var.to_s.downcase.to_sym
	namelist = namelist.to_s.sub(/_(?<num>\d+)$/, '').to_sym
	enum = $~ ? $~[:num] : nil
	return if rcp.namelists[namelist] and rcp.namelists[namelist][:variables].map{|v, h| (h[:code_name] or v).to_s.downcase.to_sym}.include? var
	namelists = rcp.namelists
	_namelist_file = 'namelists.rb'
# 	end
	raise "This namelist: #{namelist} should have an enumerator and does not have one" if enum and (not rcp.namelists[namelist] or not rcp.namelists[namelist][:enumerator])
  unless CodeRunner.global_options(:non_interactive)
  	return unless Feedback.get_boolean("An unknown variable has been found in this input file: \n\n\t Namelist: #{namelist}, Name: #{code_name}, Sample Value: #{value.inspect}.\n\nDo you wish to add it to the CodeRunner module? (Recommended: answer yes as long as the variable is not a typo)")
  end

	while nms = variable_exists?(namelist, var)
		puts "This variable: #{var} already exists in these namelists: #{nms}. Please give an alternative name for CodeRunner (this will not affect the name that appears in the input file). If you know that the variable has the same meaning in these other namelists, or if you know that none of these namelists will appear at the same time, enter '0' to leave it unchanged."
		ans = STDIN.gets.chomp
		break if ans == "0"
		var = ans.to_sym
	end
		
	namelists[namelist] ||= {}
	namelists[namelist][:description] ||= ""
	namelists[namelist][:should_include] ||= "true"
	namelists[namelist][:variables] ||= {}
	raise "Shouldn't have got here" if namelists[namelist][:variables][var]
	_tst = nil

	case value
	when Float
		#tst = "Tst::FLOAT"
		newtst = "kind_of? Numeric"
		explanation = "This variable must be a floating point number (an integer is also acceptable: it will be converted into a floating point number)."
		type = :Float
	when Integer
		#tst = "Tst::INT"
		newtst = "kind_of? Integer"
		explanation = "This variable must be an integer."
		type = :Integer
	when *String::FORTRAN_BOOLS
		#tst = "Tst::FORTRAN_BOOL"
		newtst = "kind_of? String and FORTRAN_BOOLS.include? self"
		explanation = "This variable must be a fortran boolean. (In Ruby this is represented as a string: e.g. '.true.')" 
		type = :Fortran_Bool
	when String
		#tst = "Tst::STRING"
		newtst = "kind_of? String"
		explanation = "This variable must be a string."
		type = :String
	when Complex
		#tst = "true"
		newtst = "kind_of? Complex"
		explanation = "This variable must be a complex number."
		type = :Complex
	end
	namelists[namelist][:variables][var] = {
		should_include: "true", 
		description: nil, 
		help: nil, 
		code_name: code_name, 
		must_pass: [{
			test: newtst, 
			explanation: explanation
		}], 
		type: type
	}
	if enum
		attr_accessor (var + "_#{enum}").to_sym
	else
		attr_accessor var
	end
  save_namelists
	edit_variable_help(namelist, var) unless CodeRunner.global_options(:non_interactive)
# 	folder = File.dirname(__FILE__)
# 	File.open(folder + '/' + namelist_file, 'w'){|f| f.puts namelists.pretty_inspect}
end	

# A one off function designed to correct an old error in the namelists

def self.correct_type_location
	rcp.namelists.values.each do |namelist_hash|
		namelist_hash[:variables].each do |var, var_hash|
			if var_hash[:must_pass][0] and  var_hash[:must_pass][0][:type]
			 var_hash[:type] = 	 var_hash[:must_pass][0][:type]
			 var_hash[:must_pass][0].delete(:type)
			 #pp var_hash
			end
		end
	end
	save_namelists
end


# Write the namelist database to the file namlists.rb.

def self.save_namelists
	File.open(rcp.code_module_folder + '/namelists.rb', 'w'){|f| f.puts rcp.namelists.pretty_inspect}
end

# Write the list of old variables to the file deleted_variables.rb
def self.save_deleted_variables
	File.open(rcp.code_module_folder + '/deleted_variables.rb', 'w'){|f| f.puts rcp.deleted_variables.pretty_inspect}
end

# Sets the allowed values for the variable <tt>var</tt> in <tt>namelist</tt>.

def self.set_allowed_values(namelist=nil, var, values)
	unless namelist
		namelist = rcp.namelists.find{|n, nh| nh[:variables].keys.include? var}[0]
		eputs "Editing namelist #{namelist}"; STDIN.gets
	end
	rcp.namelists[namelist][:variables][var][:allowed_values] = values
	save_namelists
end

# Add a test which the variable must pass before being included in the 
# input file. The parameter <tt>tst</tt> must be of the form:
# 	{
# 		test: test_string
# 		explanation: explanation_string
# 	}
# where test_string is a string such that 
# 	variable_value.instance_eval(test_string)
# should be <tt>true</tt> when the variable_value passes the test. The
# explanation should be a string which explains what the test does.
# 		
# If variable_value fails the test, an error is raised.

def self.add_variable_must_pass(namelist=nil, var, tst)
	unless namelist
		namelist = rcp.namelists.find{|n, nh| nh[:variables].keys.include? var}[0]
		eputs "Editing namelist #{namelist}"; STDIN.gets
	end
	rcp.namelists[namelist][:variables][var][:must_pass] ||= []
	rcp.namelists[namelist][:variables][var][:must_pass].push tst
	rcp.namelists[namelist][:variables][var][:must_pass].uniq!
	save_namelists
end

# Add a test which the namelist must pass before being included in the 
# input file. The parameter <tt>tst</tt> must be of the form:
# 	{
# 		test: test_string
# 		explanation: explanation_string
# 	}
# where test_string is a string such that 
# 	run.instance_eval(test_string)
# should be <tt>true</tt> when the run to be submitted passes the test. The
# explanation should be a string which explains what the test does.
# 		
# If the run to be submitted fails the test, an error is raised.

def self.add_namelist_must_pass(namelist, tst)
	rcp.namelists[namelist][:must_pass] ||= []
	rcp.namelists[namelist][:must_pass].push tst
	rcp.namelists[namelist][:must_pass].uniq!
	save_namelists
end

# Add a test which the variable should pass before being included in the 
# input file. The parameter <tt>tst</tt> must be of the form:
# 	{
# 		test: test_string
# 		explanation: explanation_string
# 	}
# where test_string is a string such that 
# 	variable_value.instance_eval(test_string)
# should be <tt>true</tt> when the variable_value passes the test. The
# explanation should be a string which explains what the test does.
# 		
# If variable_value fails the test, a warning is given.
#
def self.add_variable_should_pass(namelist=nil, var, tst)
	unless namelist
		namelist = rcp.namelists.find{|n, nh| nh[:variables].keys.include? var}[0]
		eputs "Editing namelist #{namelist}"; STDIN.gets
	end
	rcp.namelists[namelist][:variables][var][:should_pass] ||= []
	rcp.namelists[namelist][:variables][var][:should_pass].push tst
	rcp.namelists[namelist][:variables][var][:should_pass].uniq!
	save_namelists
end

# Add a test which the namelist should pass before being included in the 
# input file. The parameter <tt>tst</tt> must be of the form:
# 	{
# 		test: test_string
# 		explanation: explanation_string
# 	}
# where test_string is a string such that 
# 	run.instance_eval(test_string)
# should be <tt>true</tt> when the run to be submitted passes the test. The
# explanation should be a string which explains what the test does.
# 		
# If the run to be submitted fails the test, a warning is given.

def self.add_namelist_should_pass(namelist, tst)
	rcp.namelists[namelist][:should_pass] ||= []
	rcp.namelists[namelist][:should_pass].push tst
	rcp.namelists[namelist][:should_pass].uniq!
	save_namelists
end


# This regex is used to parse a Fortran namelist style input file. 

@matching_regex = Regexp.new('(^|\A)(?<everything>[^!
]*?\b	#a word boundary
	
	(?<name>[A-Za-z_]\w*)  # the name, which must be a single word (not beginning 
					# with a digit) followed by

	\s*=\s*    # an equals sign (possibly with whitespace either side), then

	(?<default>(?>    # the default answer, which can be either:

		(?<string>' + Regexp.quoted_string.to_s + ')      # a quoted string 

		|						# or

                             
                (?<float>\-?(?:(?>\d+\.\d*)|(?>\d*\.\d+))(?:[eEdD][+-]?\d+)?) # a floating point number
		
		|						#or

		(?<int>\-?\d++)	# an integer

		|					#or

                (?<complex>\((?:\-?(?:(?>\d+\.\d*)|(?>\d*\.\d+))(?:[eEdD][+-]?\d+)?),\s*(?:\-?(?:(?>\d+\.\d*)|(?>\d*\.\d+))(?:[eEdD][+-]?\d+)?)\)) #a complex number

		|					#or


		(?:(?<word>\S+)(?=\s|\)|\]|[\n\r]+|\Z)) # a single word containing no spaces 
						# which must be followed by a space or ) or ] or \n or \Z

	)))', Regexp::EXTENDED)

	class_accessor :matching_regex
	

# Parses a Fortran namelist input file into a hash of 
# 	{
# 		:namelist => {
# 			:variable => value
# 		}
# 	}
	
def self.parse_input_file(input_file, strict=true)
	if FileTest.file? input_file
		text = File.read(input_file)
	else
		text = input_file
	end
	namelist_hash = {}
	regex = Regexp.new("#{rcp.matching_regex.to_s}\\s*(?:\\!(?<comment>.*))?\\n")
	#ep input_file
	text.scan(/(?:(?:^|\A)\s*\!\s*(?<namelist_comment>[^\n]+)\n)?(?:^|\A)\&(?<namelist>\S+).*?^\//m) do 
		namelist = $~[:namelist].downcase.to_sym
		hash = namelist_hash[namelist] = {}
		#p $~
		scan_text_for_variables($~.to_s).each do |var, val|
			#ep ['Varval', var, val]
			add_code_variable_to_namelist(namelist, var, val) if @strict
			hash[var] =  val
		end
	end
 	#pp 'inputfile', namelist_hash
	namelist_hash
end

# Scan the text of a namelist from an input file and return an array variables with their default values

def self.scan_text_for_variables(text)
	regex = Regexp.new("#{rcp.matching_regex.to_s}\\s*(?:\\!(?<comment>.*))?(?:\\n|;|\\Z)")
	arr = []
	#ep ['scanning text', text]
	text.scan(regex) do
		match = $~
		#ep ['scan_match', match]
		var = match[:name].downcase.to_sym
		default = match[:default.to_sym]
		default = (match[:float] or match[:complex]) ? match[:default].gsub(/(\.)(\D|$)/, '\10\2').gsub(/[dD]/, 'e').gsub(/(\D|^)(\.)/, '\10\2') : match[:default]
 		#ep 'default', default
		default = eval(default) unless match[:word] or match[:complex]
		default= Complex(*default.scan(LongRegexen::FLOAT).map{|f| f[0].to_f}) if match[:complex]
		arr.push [var, default]
	end
	arr
end

class << self
alias :generate_simple_namelist_hash :parse_input_file
end

# Generate input file text using the namelists, the values of the run instance variables and the customised method <tt>input_file_header</tt>.

def input_file_text
	text = input_file_header
	rcp.namelists.each do |namelist, hash|
		next if hash[:should_include].kind_of? String and not eval(hash[:should_include])
		if en = hash[:enumerator] # Single = is deliberate!
			next unless send(en[:name])
			send(en[:name]).times do |i|
				next unless hash[:variables].keys.inject(false){|b, v| b or !send(v+"_#{i+1}".to_sym).nil?} # i.e. at least one variable must be non-nil 
				text << namelist_text(namelist, i+1)
			end
		else
			next unless hash[:variables].keys.inject(false){|b, v| b or !send(v).nil?} # i.e. at least one variable must be non-nil 
			text << namelist_text(namelist)
		end
			
			
	end
	text
end

def formatted_variable_output(value)
	if String::FORTRAN_BOOLS.include? value # var is a Fortran Bool, not really a string
		output = value.to_s
	elsif value.kind_of? Complex
		output = "(#{value.real}, #{value.imag})"
	#elsif value.kind_of? Array
		#output = "(/#{value.map{|v| formatted_variable_output(v)}.join(",")}/)" 
	else
		#p cr_var, cr_var.class
		output = value.inspect
	end
	output
end
# Generate the input file text for the given namelist. Called by input_file_text.

def namelist_text(namelist, enum = nil)
	hash = rcp.namelists[namelist]
	text = ""
	ext = enum ? "_#{enum}" : ""
	text << "!#{'='*30}\n!#{hash[:description]} #{enum} \n!#{'='*30}\n" if hash[:description]
	text << "&#{namelist}#{ext}\n"
	hash[:variables].each do |var, var_hash|
		code_var = (var_hash[:code_name] or var)
		cr_var = var+ext.to_sym 
		value = send(cr_var)
		if send(cr_var) and (not var_hash[:should_include] or  eval(var_hash[:should_include]))
			if value.kind_of? Array
				value.each_with_index do |v, i|
					output = formatted_variable_output(v)
					text << " #{code_var}(#{i+1}) = #{output} #{var_hash[:description] ? "! #{var_hash[:description]}": ""}\n"
				end
			else
				output = formatted_variable_output(value)
				text << " #{code_var} = #{output} #{var_hash[:description] ? "! #{var_hash[:description]}": ""}\n"
			end
		elsif rcp.namelists_to_print_not_specified? and rcp.namelists_to_print_not_specified.include?(namelist) 
			text << "  ! #{code_var} not specified --- #{var_hash[:description]}\n"
		end
	end
	text << "/\n\n"
	text
end

# Return the hash of variable properties if it exists. Else return nil

def self.find_variable_hash(var)
	varhash = nil
	rcp.namelists.each do |namelist, hash|
		varhash  = hash[:variables][var]
		return varhash if varhash 
	end
	return nil
end

# Print help for the given variable to STDOUT.

def self.help_input(var=ARGV[2].to_sym)
	eputs "\n------------ Help for '#{var}' -----------------"
	eputs "\n#{(rcp.variables_with_help[var] or "No help currently available")}\n"
	varhash = find_variable_hash(var)
  namelists = rcp.namelists.find_all{|namelist, hash| hash[:variables].keys.include? var.to_sym}.map{|n,h| n}
  eputs "\nFound in namelists: #{namelists.inspect}"
	return unless varhash
	eputs "This variable must take one of the following values: \n\t#{(varhash[:allowed_values] or varhash[:text_options])}" if (varhash[:allowed_values] or varhash[:text_options])
	eputs "\n-------- Autoscanned Defaults for '#{var}' --------------\n\nIf this variable is not specified it may be given one of these default values:\n\t#{rcp.variables_with_autoscanned_defaults[var].inspect.sub(/^\[/, '').sub(/\]$/, '')}\n in the code. These values have been automatically scanned from the source code and do not constitute a recommendation; they may raise an error."
	eputs "\n-------- Must Pass Tests for '#{var}' --------------\n\nThe variable must pass the following tests:\n\n"
	varhash[:must_pass].each do |hash|
		eputs "\tTest: #{hash[:test]}" 
		eputs "\tExplanation: #{hash[:explanation]}"
	end
	eputs
end


# Print out a list of every variable with help attached. 

def self.help_variables
	max_length = rcp.variables.map{|var| var.to_s.length}.inject{|old, new| [old,new].max}
	# + "-" * ([max_length - var.length - 8, 0].max)
	eputs rcp.variables_with_help.map{|var, comment| "#{var.to_s.rjust(max_length)}---> #{comment}"}.find_all{|string| not string =~ /^\s*\w+_[ie]/}
end

# This method compares two different input files and prints out a hash summarising the differences between them.

def self.diff_input_files(file1 = ARGV[2], file2 = ARGV[3])

  rcp.runner.update if [file1, file1].find{|file| file =~ /^\d+$/}
	file1, file2 = [file1, file2].map{|file| (run = rcp.runner.run_list[file.to_i]; file = "#{run.directory}/#{run.run_name}.in") if file.to_s =~ /^\d+$/; file}
	hash1 = generate_simple_namelist_hash(file1)
	hash2 = generate_simple_namelist_hash(file2)
	new_hash = {}
	(hash1.keys + hash2.keys).uniq.each do |key|
		unless hash1[key] and hash2[key]
			new_hash[key] = hash1[key] ? "Missing in #{File.basename(file2)} (Right)" : "Missing in #{File.basename(file1)} (Left)"
		else
			new_hash[key] = {}
			(hash1[key].keys + hash2[key].keys).uniq.each do |vkey|
# 				p vkey
				unless hash1[key][vkey].hash == hash2[key][vkey].hash
					new_hash[key][vkey] = [hash1[key][vkey], hash2[key][vkey]]
				end
			end
		end
	end
	eputs new_hash.pretty_inspect
end

# This method doesn't quite work. It is supposed to edit a local copy of a defaults file and update it to reflect any changes made to the central defaults file, without overriding any changes made to the local defaults file.

def self.update_folder_defaults #updates the defaults file in the current folder to add any new defaults settings from the given modlet. Does NOT change exist settings
	current =  File.read((defaults_file = rcp.modlet + '_defaults.rb'))
	updated = File.read("#{rcp.modlet_location}/#{defaults_file}")
	hash = current.scan(/(^\s*\@(\w+).*)/).inject({}) do |hash, (all, name)|
		hash[name] = all unless name.to_s =~ /iphi00/
		hash
	end
# 	new_hash = {}
	updated.scan(/(^\s*\@(\w+).*)/).each do |all, name|
		next if name.to_s =~ /iphi00/
		unless SPECIES_DEPENDENT_VARIABLES.include? name.sub(/_\d+$/, '').to_sym
			hash[name] = all unless hash[name]
		else
# 			puts name
			name.sub(/_1$/, '')
			if hash[name.sub(/_1$/, '_i').sub(/_2$/, '_e')]
				hash[name] = hash[name.sub(/_1$/, '_i').sub(/_2$/, '_e')].sub(/_i\b/, '_1').sub(/_e\b/, '_2')
				hash.delete(name.sub(/_1$/, '_i').sub(/_2$/, '_e'))
			elsif hash[name.sub(/_1$/, '')]
				ep name
				hash[name] = hash[name.sub(/_1$/, '')].sub(/(^\@\w+)/, '\1_1')
				hash.delete(name.sub(/_1$/, ''))
			else
				hash[name] = all
			end
		end
	end
# 	eputs hash.pretty_inspect
# 	puts hash.values
	hash['adiabatic_option'] ||= %[@adiabatic_option = "iphi00=2"]
	puts hash.values

	# 	File.open(defaults_file, 'w'){|file| file.puts hash.values}

end

# Makes a new defaults file from the given input file, copies it to the user defaults location and then sets the folder up to use it
def self.use_new_defaults_file(name=ARGV[-2], input_file=ARGV[-1])
	raise "Please specify a name and an input file" if name == "use_new_defaults_file"
	defaults_filename = "#{name}_defaults.rb"

	central_defaults_filename = defaults_location_list[0] + "/" + defaults_filename
	raise "Defaults file: #{central_defaults_filename} already exists" if FileTest.exist? central_defaults_filename
	make_new_defaults_file(name, input_file)
	FileUtils.mv(defaults_filename, central_defaults_filename)
  if Repository.repo_folder
    repo = Repository.open_in_subfolder(Dir.pwd)
    repo.add(central_defaults_filename)
    repo.autocommit("Added defaults file #{defaults_filename}")
  end #{defaults_filename}")
#end #{defaults_filename}")
  #end

	#modlet = rcp.modlet? ? rcp.modlet : nil
	#executable = rcp.executable? ? rcp.executable : CodeRunner::DEFAULT_RUNNER_OPTIONS
	#CodeRunner.fetch_runner(D: name) #(C: rcp.code, m: rcp.modlet, D: name, CodeRunner)
	CodeRunner.fetch_runner(C: rcp.code, m: (rcp.modlet? ? rcp.modlet : nil), D: name) #CodeRunner)
end

# The name is self-explanatory: this method takes an input file and generates a CodeRunner defaults file. The first argument is the name of the new defaults file.

def self.make_new_defaults_file(name=ARGV[-2], input_file=ARGV[-1])
	raise "Please specify a name and an input file" if name == "make_new_defaults_file"
	string = defaults_file_text_from_input_file(input_file)
	defaults_filename = "#{name}_defaults.rb"
	raise "This defaults name already exists" if FileTest.exist? defaults_filename
	File.open(defaults_filename, 'w'){|file| file.puts(string)}
end

# Called by defaults_file_text_from_input_file.

def self.namelist_defaults_text(hash, namelist, namelist_hash, enum = nil)
	ext = enum ? "_#{enum}" : ""
	namelist = namelist + ext.to_sym
	return "" unless hash[namelist]
	text = "\n\n######################################\n# Defaults for namelist #{namelist}\n#######################################\n\n"
# 	pp hash[namelist]
	namelist_hash[:variables].each do |var, varhash|
		code_var = (varhash[:code_name] or var)
		cr_var = var + ext.to_sym
		text << "@#{cr_var} = #{hash[namelist][code_var].inspect}    # #{varhash[:description]}\n" if hash[namelist][code_var]
	end
	return text
end

 
# The name is self-explanatory: this method takes an input file and generates the text of a CodeRunner defaults file.


def self.defaults_file_text_from_input_file(input_file)
	string = defaults_file_header

	hash = parse_input_file(input_file)
	#pp hash; exit
	#ep ['class', self.to_s, 'namelists', rcp.namelists.keys, 'code_long', rcp.code_long, 'namelist_hashes', rcp.namelists.values.map{|v| v.class}]
	rcp.namelists.each do |namelist, namelist_hash|
 		#ep namelist
		if namelist_hash[:enumerator]  # ie. This is an indexed namelist
      #p namelist_hash[:enumerator]
			enumerator = namelist_hash[:enumerator][:name]
			enum_hash = hash.find{|nml, nmlh| nmlh[enumerator]}
			next unless enum_hash
			#pp enum_hash
			enum = enum_hash[1][enumerator]
			enum.times{|i| string << namelist_defaults_text(hash, namelist, namelist_hash, i+1)}
		else
			string << namelist_defaults_text(hash, namelist, namelist_hash)
		end
	end
	string
end
	
	
	
# This method takes an input file and generates a CodeRunner info file. It should not be called in a folder where a CodeRunner info file already exists, as it will overwrite that info file with a less complete one.

def make_info_file(file=ARGV[-1], strict=true)
	hash = self.class.parse_input_file(file, strict)
# 	species_dependent_namelists = SPECIES_DEPENDENT_NAMELISTS.keys
	filename = File.dirname(file) + '/code_runner_info.rb'
# 		(puts "Warning: An info file exists: if you continue it will be overwritten, and the original may contain more information. Press enter to continue, Crtl + C to cancel"; gets) if FileTest.exist? filename
	
# 		pp hash, species_dependent_namelists
# 		run= new(@@runner)
	hash.each do |namelist, vars|
		num  = nil
# 		ep namelist
		namelist = namelist.to_s.sub(/\_(?<num>\d+)$/, '').to_sym
		if $~  # I.e if there was a number at the end of the namelist
# 			ep namelist
			raise "This namelist: #{namelist} should have an enumerator and does not have one" if not rcp.namelists[namelist][:enumerator]
			num = $~[:num]
		end
		vars.each do |var, value|
			#ep 'var', var
			var = (rcp.variable_names_from_code_names[var.to_sym] + (num ? "_#{num}" : "")).to_sym
# 				p var, value
			set(var, value)
		end
		set(:run_name, file.sub(/\.in/, ''))
#		p 'hello'
		File.open(filename, 'w'){|file| file.puts info_file}	
		File.open(".code_runner_version.txt", 'w'){|file| file.puts CODE_RUNNER_VERSION}
	end
# 	end
# 		ep @@variables
	
end

def self.parse_old_website_docs(file = ARGV[-1])
	text = File.read(file)
	text.scan(/Namelist:\s+<i>\s*(?<namelist>\w+).*?<\s*table(?<var_text>(?:<table.*?<\/table>|.)*?)(?=<\/table>)/m) do 
		namelist = $~[:namelist].to_sym
		ep 'namelist', namelist
		var_text = $~[:var_text]
		vars = var_text.split('<tr><th>')
		2.times{vars.shift}
	  vars.each do |var_text|
			ep var_text
			name, type, default, help = var_text.split('<td>')
			name, type, default = [name, type, default].map do |str|
				str.sub(/^\s+/, '').sub(/\s+\Z/, '').gsub(/<[^>]+>/, '')
			end
			name = name.sub(/^\s+/, '').sub(/\s+\Z/, '').gsub(/<[^>]+>/, '').to_sym
			ep 'name', name
			#begin
		  	#p	name, type, help, default, rcp.namelists[namelist][:variables][name][:autoscanned_defaults] 
			#rescue => err
				#p err
				#p namelist, name
			#end
			if rcp.namelists[namelist][:variables][name]
				names = [name]
			else
				names = name.to_s.split(/\s*,\s*/).map{|n| n.to_sym}
			end
			ep 'names', names
			help = help.gsub(/<\/?[bi]>/, '').gsub(/<br>/, '**')
			names.each do |name|
				unless rcp.namelists[namelist][:variables][name]
					var =  rcp.namelists[namelist][:variables].keys.find{|var|  rcp.namelists[namelist][:variables][var][:code_name] == name}
					raise "Can't find #{name.inspect} in #{namelist}" unless var
					name = var
				end

				begin
					sync_variable_help(namelist, name, help)
					if rcp.namelists[namelist][:variables][name][:help] =~ /<[^>]+>/
						edit_variable_help(namelist, name)
					end
				rescue => err
					p namelist, name
					raise err
				end
 
			end 



		end


	end

end

# This method takes the help written into this module for the various input parameters and writes it in a format suitable for the mediawiki page on input parameters. 

def self.write_mediawiki_documentation(filename = "#{rcp.code}_mediawiki.txt")
	File.open(filename, 'w') do |file|
	file.puts <<EOF
=Introduction=

This page lists every #{rcp.code} input parameter currently known about, along with any help available. It is intended as a reference, not an introduction. Note: some parameters are highly specialised and not intended for general use.

A full introduction to writing input files is to be written, but until then, this is an old example input file. Be aware that not every section should be included.

[[#{rcp.code} Reference Input File]]

==Format==

The parameters are divided into namelists. Each parameter has type information and written help where available. The format is:

{| border="2" cellpadding="5"
! Name !! Type !! Def !! CR Name !! Description 
|-
|-
|Name as it appears in #{rcp.code} ||  Fortran Data Type ||  Autoscanned Default(s): guesses at what the default value of this parameter will be if you do not specify it in the input file. They are usually correct.
|| CodeRunner Name: is the variable name used by [http://coderunner.sourceforge.net CodeRunner] to refer to the quantity (only given if it is different to the #{rcp.code} name). 
|
Long and detailed help for the variable
|}


==Updating this Page==

This page is automatically generated by [http://coderunner.sourceforge.net CodeRunner], but any '''changes you make will be kept''', so please feel free to contribute. Please keep to the same format as this allows easy automatic syncing of your changes with the CodeRunner database. '''Please only edit in between the <nowiki><!-- begin help --> <!-- end help --> </nowiki> or the <nowiki><!-- begin namelist help --> <!-- end namelist help --> </nowiki>  tags'''. Don't edit type/default information (or this introduction) as it will not be kept.

=Namelists=

Each #{rcp.code} module is controlled by its own namelist. For typical applications, not all 32+ namelists should appear in a single file. For a run called runname, this file should be called <tt>runname.in</tt>. In most cases, defaults are loaded for each namelist element, so that if a namelist or  element does not appear, the run will not automatically stop. (It may still be forced to stop if the defaults are incompatible with your other choices.) The namelists and defaults appear below.
EOF

	rcp.namelists.each do |namelist, hash|
		file.puts "==#{namelist}=="
		file.puts "<!--begin namelist help-->#{hash[:help]}<!--end namelist help-->"
		file.puts "\n{| border=\"2\" cellpadding=\"5\"\n! Name !! Type !! Def !! CR Name !! Description \n|-"
		hash[:variables].keys.sort.each do |var|
			var_hash = hash[:variables][var]
			#puts "==='''[[#{(var_hash[:code_name] or var)}]]'''==="
			file.puts "|-\n|'''[[#{(var_hash[:code_name] or var)}]]''' ||  #{var_hash[:type]} ||  #{(var_hash[:autoscanned_defaults]||[]).map{|v| v.to_s}.join(",")} || #{var} \n|\n<!--begin help-->*  #{hash[:variables][var][:help]} <!-- end help -->"
			#puts "''Type'': #{var_hash[:type]} "
			#puts "''Autoscanned Defaults'': #{var_hash[:autoscanned_defaults]} "
			#puts "''CodeRunner name'': #{var} "
	  #puts "\n", "#{hash[:variables][var][:help]}".sub(/\A\s+/, '') if hash[:variables][var][:help]
			#puts " #{(var_hash[:code_name] or var)} Properties:"
		end
		file.puts "|}"
	end
	end #file.open
end
			
# This method takes the help written into this module for the various input parameters and writes it in a format suitable for the mediawiki page on input parameters. 

#def self.write_mediawiki_documentation
	#rcp.namelists.each do |namelist, hash|
		#puts "==#{namelist}=="
		#puts hash[:help]
		#hash[:variables].keys.sort.each do |var|
			#var_hash = hash[:variables][var]
			##puts "==='''[[#{(var_hash[:code_name] or var)}]]'''==="
			#puts "* '''[[#{(var_hash[:code_name] or var)}]]''':<!-- begin help --> #{hash[:variables][var][:help]}<!-- end help -->"
			#puts "** Properties: \n*** ''Type'': #{var_hash[:type]} \n*** ''Autoscanned Defaults'': #{var_hash[:autoscanned_defaults]} \n*** ''CodeRunner Name'': #{var}"
			##puts "''Type'': #{var_hash[:type]} "
			##puts "''Autoscanned Defaults'': #{var_hash[:autoscanned_defaults]} "
			##puts "''CodeRunner name'': #{var} "
	  ##puts "\n", "#{hash[:variables][var][:help]}".sub(/\A\s+/, '') if hash[:variables][var][:help]
			##puts " #{(var_hash[:code_name] or var)} Properties:"
		#end
	#end
#end

	
#def self.write_wiki_documentation
	#rcp.namelists.each do |namelist, hash|
		#puts "==#{namelist}=="
		#puts hash[:help]
		#hash[:variables].keys.sort.each do |var|
			#var_hash = hash[:variables][var]
			##puts "==='''[[#{(var_hash[:code_name] or var)}]]'''==="
			#puts "'''[[#{(var_hash[:code_name] or var)}]]'''"
			#puts "\n<font color=gray>''Type'': #{var_hash[:type]} ''Autoscanned Defaults'': #{var_hash[:autoscanned_defaults]} ''CodeRunner name'': #{var}</font>"
			#puts "<!-- begin help --> #{"#{hash[:variables][var][:help]}".sub(/\*{1}/, "\n").sub(/\*\*/, "*")}<!-- end help -->" 
			##puts "''Type'': #{var_hash[:type]} "
			##puts "''Autoscanned Defaults'': #{var_hash[:autoscanned_defaults]} "
			##puts "''CodeRunner name'': #{var} "
	  ##puts "\n", "#{hash[:variables][var][:help]}".sub(/\A\s+/, '') if hash[:variables][var][:help]
			##puts " #{(var_hash[:code_name] or var)} Properties:"
		#end
	#end
#end

# This method scans the source code in the given folder and tries to find what value each parameter will be given if the value is not specified in the input file. It is about as subtle as a sledgehammer and doesn't always find the right answer, but in general is pretty good. The values it finds are stored in the name list hashes as :autoscanned_defaults

def self.update_defaults_from_source_code(source_code_folder = ARGV[-1])
	eputs "Scanning - this takes a while..."
	
# 	[[, File.dirname(__FILE__) + '/namelists.rb']].each do |namelists, file|
	
	namelists = rcp.namelists
# 	file = File.dirname(__FILE__) + '/namelists.rb'
	string = ""
	Dir.chdir(source_code_folder) do 
		namelists.each do |namelist, hash|
			hash[:variables].each do |var, varhash|
				string += `grep -h -E '^[ \t]*#{(varhash[:code_name] or var)}[ \t]*=' *`
				string += `grep -h -E '^[ \t]*#{(varhash[:code_name] or var)}[ \t]*=' */*`
			end
		end
	end
	
# 	string.gsub!(/^.+?:/, '') # Get rid of file names from grep
 #File.open('found1','w'){|f| f.puts string}
#  exit
	defs = scan_text_for_variables(string) 
	#File.open('found2','w'){|f| f.puts defs.pretty_inspect}
# 	exit
	namelists.each do |namelist, hash|
		hash[:variables].each do |var, varhash|
			p var if var == :nwrite
			values = defs.find_all{|(v, df)| v == (varhash[:code_name] or var)}.map{|(v,df)| df}
			values.uniq!
			p values if var == :nwrite
			values.delete_if{|val| val.kind_of? String} if values.find{|val| val.kind_of? Numeric}
			p values if var == :nwrite
			values.delete_if{|val| val.kind_of? String and not String::FORTRAN_BOOLS.include? val} if values.find{|val| val.kind_of? String and String::FORTRAN_BOOLS.include? val}
			p values if var == :nwrite
			values.sort!
			hash[:variables][var][:autoscanned_defaults] = values
# 			ep var, values
		end
	end
	save_namelists
# 	File.open(file, 'w'){|f| f.puts namelists.pretty_inspect}
# 	end
end

# Given the folder where the source code resides, return a single string containing all the code

@fortran_namelist_source_file_match = /((\.f9[05])|(\.fpp))$/

def self.get_aggregated_source_code_text(source_code_folder)
	#p 'source_code_folder', source_code_folder
	string = ""
	(rcp.source_code_subfolders.map{|f| '/' + f} + [""]).map{|f| source_code_folder + f}.each do |folder|
		Dir.chdir(folder) do 
			Dir.entries.each do |file|
				next unless file =~ rcp.fortran_namelist_source_file_match
				next if file =~ /ingen/
				ep file
				text = File.read(file) + "\n"
				text =~ /a/
				string += text
			end
		end
	end
	string
end

# Find all input namelists and variables by scanning the source code
#
def self.get_namelists_and_variables_from_source_code(source)
	nms = {}
	all_variables_in_source = {}
	namelist_declarations = {}
	#source.scan(/^\s*namelist\s*\/(?<namelist>\w+)\/(?<variables>(?:(?:&\s*[\n\r]+)|[^!\n\r])*)/) do 
	source.scan(Regexp.new("#{/^\s*namelist\s*\/\s*(?<namelist>\w+)\s*\//i}(?<variables>#{FORTRAN_SINGLE_LINE})", Regexp::IGNORECASE)) do 
		namelist = $~[:namelist].to_s.downcase.to_sym
		variables = $~[:variables].gsub(/!.*/, '')
		eputs namelist, variables
		namelist_declarations[namelist] = variables
		#gets # if namelist == :collisions_knobs

		next if [:stuff, :ingen_knobs].include? namelist
		nms[namelist] = []
		all_variables_in_source[namelist] = []
# 		puts variables
		variables.scan(/\w+/) do 
			var =  $~.to_s.to_sym
# 			(p variables, namelist; exit) if var == :following or var == :sou
			all_variables_in_source[namelist].push var
			next if known_code_variable?(namelist, var)
			nms[namelist].push var
		end
		nms[namelist].uniq!
		all_variables_in_source[namelist].uniq!
	end
	return [nms, all_variables_in_source, namelist_declarations]
end

# Try to get a sample value of the 
def self.get_sample_value(source, var)
			ep var
			values_text = source.scan(Regexp.new("\\W#{var}\\s*=\\s*.+", Regexp::IGNORECASE)).join("\n") 
			ep values_text
			values = scan_text_for_variables(values_text.sub(/_RKIND/, '')).map{|(v,val)| val} 
			values.uniq!
# 			ep values if var == :nbeta
			values.delete_if{|val| val.kind_of? String} if values.find{|val| val.kind_of? Numeric}
			values.delete_if{|val| val.kind_of? String and not String::FORTRAN_BOOLS.include? val} if values.find{|val| val.kind_of? String and String::FORTRAN_BOOLS.include? val}
# 			values.sort!
# 			ep var
# 			ep values
			sample_val = values[0]
			if not values[0] or ( values[0].kind_of? String and not String::FORTRAN_BOOLS.include? values[0])
				p source.scan(Regexp.new("^\s*(?<type>integer|float|character|logical|real|double|complex)(?:&[\\n\\r]|.)*\\W#{var}\\W", Regexp::IGNORECASE)).uniq
				p var unless $~

				case $~[:type]
				when /logical/
					sample_val = '.false.'
				when /int/
					sample_val = 0
				when 'real', 'float', 'double'
					sample_val = 0.0
				when /character/
					sample_val = ""
				when /complex/
					sample_val = Complex(0.0, 0.0)
				end
# 				type = Feedback.get_choice("Found the following possible values for '#{var}' in namelist '#{namelist}': #{values.inspect} but cannot determine its type. Please choose its type", ['Float', 'Integer', 'String', 'Unknown' ])
# 				ep type
				#n +=1
				
			end
			return sample_val
end

# Add variables found in the given namelist file and delete variables not found in it. 
#
def self.synchronise_variables_from_input_file(input_file =  ARGV[2])
	namelists = parse_input_file(input_file)
	nms = {}
	all_variables_in_source = {}
	namelist_declarations = {}
	namelists.each do |nmlist, vars|
		all_variables_in_source[nmlist.to_s.sub(/_\d+/, '').to_sym] = []
		vars.each do |var, value|
			all_variables_in_source[nmlist.to_s.sub(/_\d+/, '').to_sym].push var
			p ['nmlist', nmlist, 'var', var]
			next if known_code_variable?(nmlist, var)
			add_code_variable_to_namelist(nmlist, var, value)
		end
	end
	delete_old_variables(all_variables_in_source)
end


# Find unknown input variables in the source code and add them to the database of namelists
# Delete input variables which are no longer present in the source code
                                         
def self.synchronise_variables(source_code_folder = ARGV[2])
	source = get_aggregated_source_code_text(source_code_folder)
	nms, all_variables_in_source, namelist_declarations = get_namelists_and_variables_from_source_code(source)
	process_synchronisation(source, nms, all_variables_in_source, namelist_declarations)
end
# 	ep source.size

# Delete variables unless they are still present in the source code

def self.delete_old_variables(all_variables_in_source)
	variables_to_delete = {}	
	#pp 'namelists', rcp.namelists
	rcp.namelists.each do |namelist, namelist_hash|
		namelist_hash[:variables].each do |variable, var_hash|
			code_variable = var_hash[:code_name] || variable
			unless all_variables_in_source[namelist] and all_variables_in_source[namelist].map{|var| var.to_s.downcase.to_sym}.include? code_variable.to_s.downcase.to_sym
				variables_to_delete[namelist] ||= []
				variables_to_delete[namelist].push variable
			end
		end
	end
	variables_to_delete.each do |namelist, var_array|
		#eputs namelist_declarations[namelist]
		var_array.each do |var|
			p "Namelist: #{namelist}   Variable: #{var}"
		end
	end
	if variables_to_delete.find{|namelist, var_array| var_array.size > 0}
		#unless ENV['CR_NON_INTERACTIVE']
			delete_old = Feedback.get_boolean("These variables are no longer present in the #{rcp.code_long} source folder. Do you wish to delete them?")
		#else
			#delete_old = true
		#end
		if delete_old
			variables_to_delete.each do |namelist, var_array|
				var_array.each do |var|
					delete_variable(namelist, var)
				end
			end
		end
	end
end

def self.process_synchronisation(source, nms, all_variables_in_source, namelist_declarations)
	delete_old_variables(all_variables_in_source)

	raise "No namelists found" if nms.size == 0
	eputs nms.keys.zip(nms.values.map{|vs| vs.size})
	eputs "Namelists to be added to. (Press Enter)"; STDIN.gets unless CodeRunner.global_options(:non_interactive)
	n = 0
  ep nms
# 	ep nms.values.sum
	nms.values.sum.each do |var|
		eputs var if variable_exists? var
	end
	eputs "Conflicting Variables. (Press Enter)";; STDIN.gets unless CodeRunner.global_options(:non_interactive)
	nms.each do |namelist, vars|
		ep namelist
		ep vars
		vars.each do |var|
# 			next unless var == :w_antenna
			sample_val = get_sample_value(source, var)
			p namelist, var, sample_val
			add_code_variable_to_namelist(namelist, var, sample_val)
		end
	end
	ep n
end



#FORTRAN_SINGLE_LINE = /(?:(?:&\s*[\n\r]+)|(?:[ \t]*!.*[\n\r]+)|[^!\n\r])*/
#FORTRAN_SINGLE_LINE = /(?:(?:&\s*[\n\r]+)|(?:&[ \t]*!.*[\n\r]+)|[^!\n\r])*/
FORTRAN_SINGLE_LINE = /(?:
												(?:&[ \t]*\r?\n? #continuing line with 
												 	(?:[ \t]*!.*\r?\n?)+) # multiple comments 
												|
												  (?:&\s*[\n\r]+) # continuing line
												|
													[^!\n\r])*   # non continuing line
												/x

def self.update_text_options(source_code_folder = ARGV[-1])
	source = get_aggregated_source_code_text(source_code_folder)
	options = {}
	source.scan(/^\s*type\s*\(text_option\)\s*.*?\:\:\s*(?<var>\w+)\s+(?<options>(?:(?:&\s*[\n\r]+)|(?:\s*!.*[\n\r])|[^!\n\r])*)/) do 
			
                         name = $~[:var]
# 			 eputs $~ if name == "adiabaticopts"
			 opts =  $~[:options].scan(/text_option\('([^']+)/).flatten
			 name = "collision_model_opts" if opts.include? "krook" 
			 options[name] = opts
	end
	mapping = {}
# 	get_option_value &
#          (ginit_option, ginitopts, ginitopt_switch, &
	source.scan(/^\s*call\s*get_option_value[\s|&]*\((?<var>\w+),[\s|&]*(?<options>\w+)/) do 
#                          p $~
			 var = $~[:var].to_sym
			 op = $~[:options]
			op = "collision_model_opts" if var == :collision_model
			 mapping[var] = op
	end
# 	pp mapping
# 	pp options
# 	string_vars = []
	rcp.namelists.each do |namelist, nhash|
		nhash[:variables].each do |var, varhash|
			if varhash[:type] == :String
				if mapping[(varhash[:code_name] or var)]
					varhash[:text_options] = options[mapping[var]].uniq
# 					pp var, varhash
				end
				
			end
		end
	end
	save_namelists
# 	ep options, string_vars, mapping
# 	File.open(File.dirname(__FILE__) + '/namelists.rb', 'w'){|f| f.puts NAMELISTS.pretty_inspect}
end

			def self.print_doxygen_variable_documentation(variable=ARGV[2])
				#rcp.variables_with_help.each do |var, help|
					#next if var
					#puts var, "\n", help.gsub(/*/, '-'), "\n"
				#end
				#["! <CRDOC #{variable}: CodeRunner generated doc for #{variable}: edit on the wiki!>\n", " !>" + (rcp.variables_with_help[variable.to_sym]||"").gsub(
				[ " !>" + (rcp.variables_with_help[variable.to_sym]||"").gsub(
					/\<math\>/, "\\f$").gsub(
					/\<\/math\>/, "\\f$").gsub(
					/^\s*\*\*/, "  - ").gsub(
					/^\s*\#\#/, "  #- ").gsub(
					/^\s*\#/, '#- ').gsub(
					/^\s*\*/, '- ').gsub(
					/[^\A]^/, "\n  !!")].join(" ")
					#/[^\A]^/, "\n  !!"), "\n  ! </CRDOC #{variable}>"].join(" ")
					#/[^\A]^/, "\n  !!"), "\n  !!- NB, this is automatically generated documentation for an input parameter... see also the wiki page!", "\n  ! </CRDOC #{variable}>"].join(" ")

			end
			class << self
				alias :pdvd :print_doxygen_variable_documentation
			
				# Work out which module a variable is found in
				def get_variable_modules(folder=ARGV[2])
					text = get_aggregated_source_code_text(folder)
					#puts text
					modules = {}
					regex = /^\s*module\s+(\w+)((?:.|\n)*?)^\s*end\s+module\s+\g<1>/i
					#regex = /^\s*module\s+(\w+\b)/i
						p regex
					text.scan(regex) do 
						p $~[1]
						modules[$~[1].to_sym] = $~[2]
					end
					#pp modules
				

					rcp.namelists.each do |nmlist, hash|
						hash[:variables].each do |var, varhash|
							#regex = Regexp.new("module\\s+(\\w+)(?:.|\\n)*?public.*?(#{var})(?:.|\\n)*?namelist(#{FORTRAN_SINGLE_LINE})(?:.|\\n)*?end\\s+module\\s+\\1")
							#regex = Regexp.new("module\\s+(\\w+)(?:.|\\n)*?public.*?(#{var})(?:.|\\n)*?namelist(#{FORTRAN_SINGLE_LINE})")
							#regex = Regexp.new("public.*?(#{var})(?:.|\\n)*?namelist#{FORTRAN_SINGLE_LINE}#{var}")
							regex = Regexp.new("namelist#{FORTRAN_SINGLE_LINE}#{var}")
							#p regex
						 modules.each  do |m, mod|
							 mod.scan(regex) do
							  varhash[:module] = m.to_sym		
							 end
						 end
						end
					end
				save_namelists
				end			
				alias :gvm :get_variable_modules
				
				#Make a file with doxygen style comments to document
				#the input parameters
								
				def print_doxygen_documentation
					puts "! This file is not part of GS2, but exists to document those variables which are also input parameters. It is generated automatically by CodeRunner from its input parameter database. To update this database, DO NOT edit this file,  your changes will be lost: go to the wiki page for the input parameters (http://sourceforge.net/apps/mediawiki/gyrokinetics/index.php?title=Gs2_Input_Parameters) and follow the instructions there. \n\n"

					rcp.namelists.each do |nmlist, hash|
						hash[:variables].each do |var, varhash|
							next unless varhash[:module] and varhash[:help]
							puts "module #{varhash[:module]}\n\n\n"
							puts "  #{print_doxygen_variable_documentation(var)}"
							#puts " public :: #{var}"
							puts " #{fortran_type(varhash)} :: #{var}"
							puts "end module #{varhash[:module]}"

						 end
						end
				end			
				alias :pdd :print_doxygen_documentation
				def fortran_type(varhash)
					case varhash[:type]
					when :Float
						'real'
					when :Fortran_Bool
						'logical'
					when :String
						'character'
					when :Integer
						'integer'
					else 
						raise 'unknown type'
					end
				end
			end

		end # class FortranNamelist

	end # class Run
end # class CodeRunner
