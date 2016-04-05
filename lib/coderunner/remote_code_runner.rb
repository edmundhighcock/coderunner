class RemoteCodeRunner < CodeRunner
	(CodeRunner.instance_methods - (Object.instance_methods + Log.instance_methods)).each do |meth|
		next if [:sort_runs, :print_out, :filter, :similar_runs, :get_max, :get_min, :generate_combined_ids, :setup_run_class, :get_run_class_name, :readout, :graphkit_from_lists, :graphkit, :graphkit_shorthand, :run_graphkit_shorthand, :axiskit, :filtered_ids,  :filtered_run_list, :make_film_from_lists, :sweep_graphkits, :cache, :merged_runner_info].include? meth
		next if CodeRunner::DEFAULT_RUNNER_OPTIONS.keys.include? meth
		next if CodeRunner::DEFAULT_RUNNER_OPTIONS.keys.map{|meth| (meth.to_s + '=').to_sym}.include? meth

		undef_method meth
	end
# 	class << self
# 		undef_method :graphkit_multiple_runners_from_frame_array
# 			def method_missing(method, *args)
# 		raise "Not a CodeRunner class method #{method}" unless (CodeRunner.methods + [:puts]).include? method
# 		if method.to_s =~ /=$/
# 			raise NoMethodError.new("unknown set method: #{method}")
# # 			@attributes[method] = args[0]
# # 			return
# 		end
# 		data = retrieve(method, *args)
# 		if method.to_s =~ /graphkit/
# 			return Marshal.load(data)
# 		else
# 			puts data
# 		end
# 	end
# 	end

	attr_accessor :combined_ids, :component_ids, :ids, :combined_run_list, :component_run_list, :run_list, :remote_cache, :libraries

# 	include Log
# 	puts instance_methods; exit
# 	SHOULD_NOT_BE_CALLED = :add_component
	class << self
		aliold :new
		def new(host, folder, copts = {})
			if host.length == 0
# 				p 'hello'
# 				copts[:Y] = folder
# 				copts[:no_print_out] = true
# 				copts[:no_update] = true
# 				return go(copts)
				folder.sub!(/~/, ENV['HOME'])
# 				Dir.chdir(folder){read_defaults(copts)}
# 				p copts
				return CodeRunner.new(folder, copts)
			end
			if copts[:cache]
				if copts[:cache] == :auto and FileTest.exists? cache_file(host, folder)
					begin
						runner =  Marshal.load(File.read(cache_file(host, folder)))
					rescue TypeError, ArgumentError => err
						eputs err
						eputs data [0..100] if err.class == TypeError
						raise err unless err.message =~ /undefined class/
						repair_marshal_run_class_not_found_error(err)
						retry
					end
					 runner.remote_cache = copts[:cache]
					 runner.libraries ||= []
					 return runner
				else
					runner =  old_new(host, folder, copts)
					runner.update
					runner.remote_cache = copts[:cache]
					unless FileTest.exist? cache_folder(host, folder)
						FileUtils.makedirs cache_folder(host, folder)
					end
					File.open(cache_file(host, folder), 'w') do |file|
						file.puts Marshal.dump(runner)
					end
					return runner
				end
			else
				return old_new(host, folder, copts)
			end

		end
		def cache_folder(host, folder)
			RUNNER_CACHE + "/#{host}/#{folder.gsub(/\//, '_')}"
		end
		def cache_file(host, folder)
			cache_folder(host, folder) + '/runner.msl'
		end
	end

	DISPLAY_REMOTE_INVOCATION = false

	RUNNER_CACHE = ENV['HOME'] + '/.coderunner/remote_cache/'

	def initialize(host, folder, copts = {})
		@folder = folder
		@host = host
		#eputs "setting libraries"
		@libraries = []
		if host.length == 1
			unless Object.constants.include? HostManager.to_s.to_sym
				raise CRFatal.new("Host manager not available")
			end
			HostManager.phoenix($default_host_manager_store) do |host_manager|
# 				@user_name = host_manager.hosts[host].user_name
# 				@host = host_manager.hosts[host].host
# 				@port = host_manager.hosts[host].port
				@ssh_command = host_manager.hosts[host].ssh
			end
		else
# 			@user_name, @host = host.split(/@/)
			@ssh_command = "ssh " + host
		end
# 		@coderunner_location = coderunner_location
		@attributes = {}
		process_copts(copts)
	end
	def process_copts(copts)
		@copts = copts.dup
		@copts[:g] = @copts[:G] = []
# 		@copts[:f] = nil
		@copts[:Y] = @copts[:w] = @copts[:r] = @copts[:e]  = nil
		@copts.delete(:E)
	end
	def method_missing(method, *args)
		raise "Not a CodeRunner method #{method}" unless (CodeRunner.instance_methods + [:puts]).include? method
# 		ep method; STDIN.gets

		if method.to_s =~ /=$/
			raise NoMethodError.new("unknown set method: #{method}")
# 			@attributes[method] = args[0]
# 			return
		end
		data = retrieve_method(method, *args)
		if method.to_s =~ /graphkit/
# 			puts Marshal.load(data).pretty_inspect
			unless data
				raise "Error: No data was returned from remote server when calling '#{method}'"
			end
			#return Marshal.load(data)
			return data
		else
			puts data
		end
	end
	def retrieve_method(method, *args)
		eputs "Calling Remote Method: #{method}"
    retrieve("#{method.to_s}(*#{args.inspect})")
	end
	def retrieve(string)
		#ep '@host', @host, '@remote_cache', @remote_cache
		filename = string.gsub(/[\/:\\\[\]\(\)]/, '.')
		if filename.size > 100
			require 'digest'
			filename = Digest::MD5.hexdigest(filename)
		end
    cachename = self.class.cache_folder(@host, @folder) + '/' + filename
		if @remote_cache == :auto and 	FileTest.exist?(cachename)
			data = eval(File.read(cachename))
      return data if not data.nil?
		end
		string = @libraries.map{|lib| "require #{lib}"}.join(";") + ";" + string

		eputs "Connecting to server using '#{@ssh_command}'..."
		eputs "Loading folder #{@folder}..."
# 		eval =
# 		> /dev/null 2> /dev/null > /dev/null 2> /dev/null
#{%w{ ~/.bashrc ~/.bash_login ~/.bash_profile ~/.profile}.map{|w| "source #{w} > /dev/null 2> /dev/null "}.join(" && ")}
		shell_script = <<EOF
cd #@folder
export ROWS=#{Terminal.terminal_size[0]}
export COLS=#{Terminal.terminal_size[1]}
source /etc/bashrc /etc/profile > /dev/null 2> /dev/null
#{%w{ ~/.bash_login ~/.bash_profile ~/.profile ~/.bashrc}.map{|w| "source #{w} > /dev/null 2> /dev/null "}.join(" ; ")}
if [ "$CODE_RUNNER_COMMAND" ]
	then
		$CODE_RUNNER_COMMAND runner_eval #{string.inspect} -Z #{@copts.inspect.inspect}
	else
		coderunner runner_eval #{string.inspect} -Z #{@copts.inspect.inspect}
fi

EOF
# coderunner runner_eval #{"#{method.to_s}(*#{args.inspect})".inspect} -Z #{@copts.inspect.inspect}

		eputs shell_script if DISPLAY_REMOTE_INVOCATION
		data = %x[#@ssh_command '#{shell_script}']
 		#ep data
		eputs "\nDisconnecting from server..."
		eprint "Extracting data..."
		data_arr = []
		in_dump = false
		i = 0
		loop do

			if  i>=80 #data.size
				break

			else  #if data[i-1] == "E" and data[i-2] == "_"
# 				ep data[i...(i + "code_runner_server_dump_start_E".size)], '.....'
# 			ep data[(-"code_runner_server_dump_end_E\n".size-i+1)..-i] if in_dump

# 				string = data[0...i]
	# 			p string
				if !in_dump and data[i...(i + "code_runner_server_dump_start_E".size)] == "code_runner_server_dump_start_E" #   =~ /.*Begin Output\n\Z/
# 					ep "IN DUMP"
					data = data[(i + "code_runner_server_dump_start_E".size)..-1]
					in_dump = true
					i = 0
				elsif in_dump and data[(-"code_runner_server_dump_end_E\n".size-i+1)..-i] == "code_runner_server_dump_end_E\n" #
					data_arr.push data[0...(data.size - ("code_runner_server_dump_end_E\n".size+i-1))]
# 					ep "OUT DUMP"
	# 				ep data_arr
# 					data = data[0...-(-"code_runner_server_dump_end_E".size-i)]
					in_dump = false
# 					i = 1
					break
				end
			end
			i+=1
		end

		eputs "done"
# 		ep data_arr; exit


		begin
			case data_arr.size
			when 0
				output = nil
			when 1
				output =  Marshal.load(data_arr[0])
			else
				output = data_arr.map{|str| Marshal.load(str)}
			end
		rescue TypeError, ArgumentError => err
			eputs err
			eputs data[0..100] if err.class == TypeError
			raise err unless err.message =~ /undefined class/
			self.class.repair_marshal_run_class_not_found_error(err)
			retry
		end

		if [:refresh, :auto].include? @remote_cache
			eputs "Writing Cache"
			File.open(cachename, 'w'){|file| file.puts(output.inspect)}
		end
		return output

	end
	def update
		instance_vars = retrieve_method(:marshalled_variables) #.sub(/\A\s*/, '')
		instance_vars[:@run_list].values.each{|run| run.runner=self}
		instance_vars.each do |var, val|
			case var
			when :@server, :@sys
				next
			when	:@use_phantom
			  # For backwards compatbility with versions < 0.14
				instance_variable_set(:@use_component, val)
			when :@phantom_run_list
			  # For backwards compatbility with versions < 0.14
				instance_variable_set(:@component_run_list, val)
			else
				instance_variable_set(var, val)
			end
		end
		sort_runs
		return self
	end
end

