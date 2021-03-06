class CodeRunner
	class Cubecalc < Run::FortranNamelistC
		
# @code = 'cubecalc'

@variables = [:calculate_sides, :width, :height, :depth]

@naming_pars = [:width]

@results = [:volume, :sides, :area]

# e.g. number of iterations

@run_info = [:component_run_description]

# @@executable_name = 'cubecalc'

@code_long = "Cube Volume Calculator"

@excluded_sub_folders = []

@defaults_file_name = "cubecalc_defaults.rb"

@modlet_required = true

@uses_mpi = false

@repo_file_match = /results.txt/

#@readout_list = @variables + @results

@code_module_folder = File.dirname(File.expand_path(__FILE__)) # i.e. the directory this file is in

@namelists_to_print_not_specified = []

def process_directory_code_specific
	if @running
		@status = :Incomplete
	else
		if FileTest.exist? 'results.txt'
			@status = :Complete
			@volume = File.readlines('results.txt')[0].scan(LongRegexen::FLOAT)[0][0].to_f
		else
			@status = :Failed
		end
		@sides = []
		if FileTest.exist? 'sides.txt'
			File.read('sides.txt').scan(Regexp.new("is\\s*" + LongRegexen::FLOAT.verbatim + "$")){@sides.push $~[:float].to_f}
		end
	end
end

def print_out_line
	if @is_component
		if @component_run_description == :area
			return sprintf("%d:%d %30s %10s %f %s", @id, @job_no, @run_name, @status, (@volume or 0.0), @area.to_s)
		else
			raise 'there is only one component_run_description at the moment'
		end
	else
		return sprintf("%d:%d %30s %10s %f %s", @id, @job_no, @run_name, @status, (@volume or 0.0), @sides.to_s)
	end
end

def parameter_string
	return sprintf("%d %s", @calculate_sides, 'edges.txt')
end

def generate_input_file
	File.open('edges.txt', 'w') do |file|
		file.puts @width
		file.puts @height
		file.puts @depth
	end
end
# @run_class.variables.keys[0]
def parameter_transition(run)
end

#def executable_location
	#@runner.script_folder + '/test_suite'
#end
	

def generate_component_runs
	return unless @sides
	@sides.each do |area|
# 		puts 'creating component: ' + @run_name
		component = create_component
		component.area = area
		component.component_run_description = :area
	end
end

def graphkit(name, options)
	case name
	when /sides/
# 		x = AxisKit.autocreate({data: ["'width'", "'depth'", "'height'"], name: 'Properties'})
		x = GraphKit::AxisKit.autocreate({data: sides, title: "Areas of the Sides:  #@run_name"})
# 		x.range = [0, x.data.max]
		kit = GraphKit.autocreate({x: x})
		kit.style = 'data histograms'
		kit.file_name = 'inputs'
# 		kit.with = 'histogram clustered'
		return kit
	else
		raise 'Unknown graph'
	end
end
		
		
	end
end

