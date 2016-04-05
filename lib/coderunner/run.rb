class CodeRunner

# Every code module defines a custom child class of CodeRunner::Run. This class will also include a module which customizes it to work on the current system. The result is a class which knows how to run and analyses the results of the given code on the given system. 
# 
# Every simulation that is carried out has an instance of this custom class created for it, and this object, known as a run, contains both the results and the input parameters pertaining to that simulation. All these runs are then stored in the variable run_list in a runner (an instance of the CodeRunner class). The result is that every run has a runner that it can talk to, and that runner has a set of runs that it can talk to.
#
# Every run has its own directory, where all the input and output files from the simulation are stored. CodeRunner data for the run is stored in this folder in the files <tt>code_runner_info.rb</tt> and <tt>code_runner_results.rb</tt>.  
#
# As soon as the simulation is complete, CodeRunner call Run#process_directory to carry out any anlysis, and the results are stored in <tt>code_runner_results.rb</tt>. For speed CodeRunner also caches the data in the file <tt>.code_runner_run_data</tt> in binary format. This cache will be used after the initial analysis unless CodeRunner is specifically told to reanalyse this run.
#
# All input parameters and results are available during run time as instance variables of the run class.
#
# The class CodeRunner::Run itself defines a base set of methods which are added to by the code module. 
  
class Run
  include Log
# # include CodeRunner::HeuristicRunMethods

#     class_vars = [:conditions, :sort, :sys, :debug, :script_folder, :necessary_system_runner_methods, :necessary_code_runner_methods, :recalc_all, :parallel]


# @@ruby_command = "ruby" #redefine if necessary
# @@input_file_extension = nil
# @@use_file_name_as_run_name = nil
# @@successful_trial_system = nil
# 
# @@readout_real_run_list = true
# @@print_out_real_run_list = true
# @@readout_component_run_list = false
# @@print_out_component_run_list = false


# class_accessor :readout_real_run_list, :print_out_real_run_list, :readout_component_run_list, :print_out_component_run_list, 

class_accessor :current_status, :runner

# Use the instance method #queue_status (defined in the system module) to put a list of current jobs obtained from the system into the class variable @@current_status

def self.update_status(runner)
  if runner.no_run
    @@current_status =  ""
  else
    #eputs 'Getting queue status...'
    @@current_status = new(runner).queue_status
  end
#   puts @@current_status
end


def gets #No reading from the command line thank you very much!
  $stdin.gets
end
def self.gets
  $stdin.gets
end


(SUBMIT_OPTIONS + [:code, :version, :readout_list, :naming_pars, :other_pars, :all, :ruby_command, :run_sys_name, :modlet, :executable]).each do |variable|
  #define accessors for class options and instance options
#   class_accessor(variable)
  attr_accessor variable
#   set(variable, nil) unless class_variables.include? ("@@" + variable).to_sym
end

class_accessor :run_sys_name
@@run_sys_name = nil
#   @@necessary_class_variables.keys.each{|v| send(:attr_accessor, v)}

# @runnmaxes = {}

attr_accessor :maxes, :max_complete, :version, :code, :nprocs, :executable_name, :runner, :sys, :naming_pars, :code_runner_version, :real_id

# Purely for testing purposes; see the test suite

attr_accessor :run_test_flags

# Access to a hash which is stored in the runner (not the run). The hash will persist while the runner is in the object space.
#
# E.g.
#   cache[:my_stuff_to_store] = something_to_store

def cache
  @runner.cache[:runs] ||= {} 
  @runner.cache[:runs][@id] ||= {} 
  @runner.cache[:runs][@id]
end

# Empty the cache for this run
def clear_cache
  @runner.cache[:runs] ||= {} 
  @runner.cache[:runs][@id] = {} 
end

# The hard cache persists after the current program ceases because
# it is written in the .code_runner_run_data file.
# It will disappear if the -a or -A flags are specified at any point
# If you edit the hard cache you ''must'' call <tt>save</tt> afterwards
# or your changes may not be kept
def hard_cache
  @hard_cache ||={}
  @hard_cache
end 
#def save_hard_cache
  #Dir.chdir(@directory)




  class RunClassPropertyFetcher
    def initialize(the_class)
      @my_class = the_class
    end
    def method_missing(method, value=nil)
      #eputs 'STARTING'
      if method.to_s =~ /=$/
        raise 'rcps should not be set outside class methods'
        @my_class.instance_variable_set("@"+method.to_s.sub(/=/, ''), value)
      else
        the_class = @my_class
        loop do 
          #p the_class, method
#           p the_class.instance_variables
#           p the_class.instance_variables.map{|v| the_class.instance_variable_get(v)}
          if method.to_s =~ /\?$/
            return false unless the_class
            return true if the_class.instance_variables.include?(("@"+method.to_s.sub(/\?$/,'')).to_sym)
          else
            raise NoMethodError.new("Run class property #{method} not found.") unless the_class
            return the_class.instance_variable_get("@"+method.to_s) if the_class.instance_variables.include?(("@"+method.to_s).to_sym)
          end
            the_class = the_class.superclass
        end
          
      end
    end
      
      def [](prop)
        send(prop.to_sym)
      end
#       def []=(prop, value)
#         set(prop.to_sym, value)
#       end
#     end
        
  end

# Access properties of the run class. These properties are stored as instance variables of the run class object. (Remember, in Ruby, every Class is an Object (and Object is a Class!)).
# 
# E.g.
#   puts rcp.variables

def self.rcp
  @rcp ||= RunClassPropertyFetcher.new(self)
end

# Calls Run.rcp

def rcp 
  self.class.rcp
end

# Create a new run. <tt>runner</tt> should be an instance of the class CodeRunner.

def initialize(runner)
  logf('initialize')
#   raise "runner must be either a CodeRunner or a RemoteCoderunner: it is a #{runner.class}" unless [CodeRunner, RemoteCodeRunner].include? runner.class
  @runner = runner
#   raise CRFatal.new("Code not defined: #{CODE}") unless @@code and @@code.class == String and @@code =~ /\S/  
  @sys, @code = rcp.sys, rcp.code
  @naming_pars = rcp.naming_pars.dup
  raise CRFatal.new("@modlet not specified for #{self.class}") if rcp.modlet_required and not rcp.modlet
#   @modlet = @@modlet; @modlet_location = @@modlet_location
# #   @executable_location = executable_location
#     @@necessary_run_variables.each{|v,clas| instance_eval("@#{v} = nil")}
    
#     initialize_code_specific
  
#   @script_folder  = @@script_folder
#   @recalc_all = @@recalc_all
  @wall_mins = @runner.wall_mins if @runner
  @smaxes = {}; @csmaxes = {}; @max_complete = {};
end

# Here we redefine the inspect function p to raise an error if anything is written to standard out
# while in server mode. This is because the server mode uses standard out to communicate
# and writing to standard out can break it. All messages, debug information and so on, should always
# be written to standard error.

def p(*args)
  if @runner and @runner.server
    raise "Writing to stdout in server mode will break things!"
  else
    super(*args)
  end
end

# Here we redefine the function puts to raise an error if anything is written to standard out
# while in server mode. This is because the server mode uses standard out to communicate
# and writing to standard out can break it. All messages, debug information and so on, should always
# be written to standard error.

def puts(*args)
  if @runner and @runner.server
    raise "Writing to stdout in server mode will break things!"
  else
    super(*args)
  end
end
 
# Here we redefine the function print to raise an error if anything is written to standard out
# while in server mode. This is because the server mode uses standard out to communicate
# and writing to standard out can break it. All messages, debug information and so on, should always
# be written to standard error.

def print(*args)
  if @runner and @runner.server
    raise "Writing to stdout in server mode will break things!"
  else
    super(*args)
  end
end


# Analyse the directory of the run. This should be called from the directory where the files of the run are located. This method reads in the CodeRunner data already available in <tt>code_runner_info.rb</tt> and <tt>code_runner_results.rb</tt>, and then calls <tt>process_directory_code_specific</tt> which is defined in the code module.

def process_directory
  
  # Clear the cache
  # EGH removed the two lines below because code module need the cache
  # to last, e.g. if it contains references to other files
  #@runner.cache[:runs]||={}
  #@runner.cache[:runs][@id] = {}
  logf(:process_directory)
  raise CRFatal.new("Something has gone horribly wrong: runner.class is #{@runner.class} instead of CodeRunner") unless @runner.class.to_s == "CodeRunner"

  begin
    @code_runner_version = Version.new(File.read('.code_runner_version.txt'))
    File.read('code_runner_info.rb')
  rescue Errno::ENOENT # version may be less than 0.5.1 when .code_runner_version.txt was introduced
    @code_runner_version = Version.new('0.5.0')
  end
  
  @directory = Dir.pwd
  @relative_directory = File.expand_path(Dir.pwd).sub(File.expand_path(@runner.root_folder) + '/', '')
#   p @directory
  @readme = nil
  
  #if @code_runner_version < Version.new('0.5.1')
    #begin
      #update_from_version_0_5_0_and_lower
    #rescue Errno::ENOENT => err # No code runner files were found
      #unless @runner.heuristic_analysis
        #puts err
        #raise CRFatal.new("No code runner files found: suggest using heuristic analysis (flag -H if you are using the code_runner script)")
      #end
      #unless @runner.current_request == :traverse_directories
        #@runner.requests.push :traverse_directories unless @runner.requests.include? :traverse_directories
        #raise CRMild.new("can't begin heuristic analysis until there has been a sweep over all directories") # this will get rescued
      #end
      #@runner.increment_max_id 
      #@id = @runner.max_id
      #@job_no = -1
      #run_heuristic_analysis
    #end
  #end
    begin
      read_info
    rescue Errno::ENOENT => err # No code runner files were found
      unless @runner.heuristic_analysis
        puts err
        raise CRFatal.new("No code runner files found: suggest using heuristic analysis (flag -H if you are using the code_runner script)")
      end
      unless @runner.current_request == :traverse_directories
        @runner.requests.push :traverse_directories unless @runner.requests.include? :traverse_directories
        raise CRMild.new("can't begin heuristic analysis until there has been a sweep over all directories") # this will get rescued
      end
      @runner.increment_max_id  
      @id = @runner.max_id
      @job_no = -1
      run_heuristic_analysis
    end
  
  
  @cr_has_read_results = false
  if FileTest.exist? 'code_runner_results.rb'
    begin
      read_results
      @cr_has_read_results = true
    rescue NoMethodError, SyntaxError => err
      puts err
      puts 'Results file possibly corrupted for ' + @run_name
    end 
  end

  @running = (@@current_status =~ Regexp.new(@job_no.to_s)) ? true : false 
  if @running and methods.include? :get_run_status
    @status = get_run_status(@job_no, @@current_status) rescue :Unknown
  else
    @status ||= :Unknown
  end
  #logi '@@current_status', @@current_status, '@job_no', @job_no
  #logi '@running', @running
  if not @cr_has_read_results or @running or not [:Complete, :Failed].include? @status or @runner.recalc_all or @runner.reprocess_all
    process_directory_code_specific 
  end 
  
  # Sometimes the run can be completed and still in the queue, in
  # which case process_directory_code_specific may set @status==:Complete
  # or @status==:Failed even though @running = true. Here we update
  # @running if this is the case. This will have no effect on any subsequent
  # update as CodeRunner does not use @running as a criterion for deciding
  # whether or not to recheck a run and call process_directory again.
  @running = false if [:Complete, :Failed].include? @status
  
  raise CRFatal.new("status must be one of #{PERMITTED_STATI.inspect}") unless PERMITTED_STATI.include? @status
  @max = {}
  write_results
  @component_runs = []
  generate_component_runs
  save
  commit_results if @runner.is_in_repo? and not @running
  return self
end

# Read input parameters from the file <tt>code_runner_info.rb</tt>

def read_info
  eval(File.read('code_runner_info.rb')).each do |key, value|
    set(key, value)
  end
end

# Read results from the file <tt>code_runner_results.rb</tt>

def read_results
  return if @runner.recalc_all
  eval(File.read('code_runner_results.rb')).each do |key, value|
    set(key, value)
  end
end

# Write results to the file <tt>code_runner_results.rb</tt>

def write_results
  logf(:write_results)
  Dir.chdir(@directory){File.open("code_runner_results.rb", 'w'){|file| file.puts results_file}}
end

# Return the text of the results file.

def results_file
  logf(:results_file)
  return <<EOF
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# #{rcp.code_long} Results
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#
# This is a syntactically correct Ruby file, which is used by CodeRunner. Please do not edit unless you know what you are doing.
# Directory:  #{@directory}
# Runname:  #{@run_name}
# ID:   #{@id}

# Results:
#{(rcp.results+rcp.run_info - [:component_runs]).inject({}){|hash, (var,_type_co)| hash[var] = send(var); hash}.pretty_inspect}

# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
EOF

end

# Return a line of data for printing to file in CodeRunner#readout, organised according to the run class property rcp.readout_list 

def data_string
  rcp.readout_list.inject(""){|str,var| str+"#{send(var)}code_runner_spacer"}.gsub(/\s/, '_').gsub(/code_runner_spacer/, "\t") + "\n" 
end

# Used for the status with comments command.

def comment_line
  #"#{id}: #{@comment}"
  sprintf("%2d:%d %1s:%2.1f(%s) %3s%1s %s",  @id, @job_no, @status.to_s[0,1],  @run_time.to_f / 60.0, @nprocs.to_s, percent_complete, "%", @comment)
end

# Cache the run object in the file <tt>.code_runner_run_data</tt>

def save
  
  logf(:save)
  raise CRFatal.new("Something has gone horribly wrong: runner.class is #{@runner.class} instead of CodeRunner") unless @runner.class.to_s =~ /^CodeRunner(::Merged)?/
  runner, @runner = @runner, nil
  @system_triers, old_triers = nil, @system_triers
  @component_runs.each{|run| run.runner = nil} if @component_runs
  #@component_runs.each{|run| run.runner = nil} if @component_runs
#   logi(self)
  #pp self
  Dir.chdir(@directory){File.open(".code_runner_run_data", 'w'){|file| file.puts Marshal.dump(self)}}
  @runner = runner
  @component_runs.each{|run| run.runner = runner} if @component_runs
  @system_triers = old_triers 
end


# Load the run object from the file <tt>.code_runner_run_data</tt>

def self.load(dir, runner)
  raise CRFatal.new("runner supplied in Run.load was not an instance of code runner; runner.class = #{runner.class}") unless runner.class.to_s == "CodeRunner"
  begin
    raise CRMild.new("No saved run data") unless FileTest.exist? (dir+"/.code_runner_run_data")
    run = Marshal.load(File.read(dir+"/.code_runner_run_data"))
  rescue ArgumentError => err
    raise err unless err.message =~ /undefined class/
    #NB this means that all code_names have to contain only lowercase letters:
#     code, modlet = err.message.scan(/CodeRunner\:\:([A-Z][a-z0-9]+)((?:[A-Z]\w+)+)?Run/)[0]
#     code, modlet = err.message.scan(/CodeRunner\:\:([A-Z][a-z0-9_]+)(?:::([A-Z]\w+))?/)[0]
#     ep code, modlet; exit
#     code.gsub!(/([a-z0-9])([A-Z])/, '\1_\2')
#     modlet.gsub!(/([a-z0-9])([A-Z])/, '\1_\2')
#     ep err, modlet, code
#     runner.setup_run_class(code.downcase, modlet: modlet.downcase)
#     retry
    CodeRunner.repair_marshal_run_class_not_found_error(err)
    run = Marshal.load(File.read(dir+"/.code_runner_run_data"))   
  end
  run.runner = runner
  raise CRFatal.new("Something has gone horribly wrong: runner.class is #{run.runner.class} instead of CodeRunner") unless run.runner.class.to_s == "CodeRunner"
  run.directory = dir
  # For backwards compatibility with versions < 0.14
  run.instance_variable_set(:@component_run_list, run.instance_variable_get(:@phantom_run_list)) if run.instance_variable_get(:@phantom_run_list) 
  run.component_runs.each{|r| runner.add_component_run(r); r.runner = runner} if run.component_runs
  #@component_runs = []
  return run
end

# Return the name of the defaults file currently in use.

def defaults_file_name
  if @runner.defaults_file
    return "#{@runner.defaults_file}_defaults.rb"
  else
    return "#{rcp.code}_defaults.rb"
  end
end

@code_module_folder = "/dev/null"

# A list of places where defaults files may be found

def self.defaults_location_list
  locs = [rcp.user_defaults_location, rcp.code_module_folder + "/defaults_files"]
  if Repository.repo_folder
    repo = Repository.open_in_subfolder(Dir.pwd)
    folder = repo.dir.to_s + '/defaults_files/' + rcp.code + 'crmod/'
    FileUtils.makedirs folder
    locs.unshift folder
  end
  locs
end

def defaults_location_list
  self.class.defaults_location_list
end

# Return the folder where the default defaults file is located.

def defaults_location
  location = defaults_location_list.find{|folder| FileTest.exist? folder and Dir.entries(folder).include? defaults_file_name}
  #raise "Can't find defaults_file #{defaults_file_name} in #{defaults_location_list.join(',')}." unless location
  location
end

# Return true if the run is completed, false otherwise

def is_complete
  @status == :Complete
end

alias :ctd :is_complete

# This function is a hook which is used by system modules. For runs it is defined as the id. 

def job_identifier
  id
end

class NoRunnerError < StandardError
  def new(mess)
    super("No Runner: a runner was needed for this Run method call "+mess)
  end
end

# Update instance variables using the given defaults file. Give warnings if the defaults file contains variables which are not simulation input parameters

def evaluate_defaults_file(filename)
  text = File.read(filename)
  text.scan(/^\s*@(\w+)/) do
    var_name = $~[1].to_sym
    next if var_name == :defaults_file_description
    unless rcp.variables.include? var_name
      warning("---#{var_name}---, specified in #{File.expand_path(filename)}, is not a variable. This could be an error")
    end
  end
  instance_eval(text)
end

#  This function set the input parameters of the run using the following sources in ascending order of priority: main defaults file (in the code module folder), local defaults file (in the local Directory), parameters (an inspected hash usually specified on the command line).

def update_submission_parameters(parameters, start_from_defaults=true)
  logf(:update_submission_parameters)
  if start_from_defaults
    #upgrade_defaults_from_0_5_0 if self.class.constants.include? :DEFAULTS_FILE_NAME_0_5_0
    #

    if not defloc=defaults_location
      info("Could not find central defaults file... using local defaults only")
      if not FileTest.exist? defaults_file_name
        raise "Cannot find #{defaults_file_name} either centrally or locally"
      end
    else

      main_defaults_file = "#{defloc}/#{defaults_file_name}"
      main_defaults_file_text =     File.read(main_defaults_file)
      evaluate_defaults_file(main_defaults_file)

      unless FileTest.exist?(defaults_file_name)
        main_defaults_file_text.gsub!(/^/, "#")
        header = <<EOF
#############################################################
# CodeRunner Local Defaults File 
############################################################
#
# This is a local copy of the central defaults file, which 
# was copied from the central defaults file 
#   #{defaults_file_name} 
# 
# to the folder
#   #{Dir.pwd}
#
# at 
#   #{Time.now}
#
# by CodeRunner version #{CODE_RUNNER_VERSION}
#
# All lines in the original file have been commented out:
# they are kept as a reference to make adding local defaults easier. 
# It is suggested that local changes are placed at the top 
# of this file, not in the body of the commented out section.
#
# Local changes override the central defaults file. However,
# if the central defaults file changes, any variables which 
# are not overidden here will change for any future simulations
# in this folder.
#
##############################################################






# Begin Copy of Central Defaults:
#
#
EOF
        main_defaults_file_text = header + main_defaults_file_text
        File.open(defaults_file_name, 'w'){|file| file.puts main_defaults_file_text}
        if @runner.is_in_repo?
          repo = Repository.open_in_subfolder(Dir.pwd)
          repo.add(defaults_file_name)
          repo.autocommit("Added local defaults file #{defaults_file_name} in folder #{Dir.pwd}")
        end
                                                                                       #{defaults_file_name} in folder #{Dir.pwd
                                                                                       ##{defaults_file_name} in folder #{Dir.pwd
                                                                                       #
      end
    end
    #FileUtils.cp("#{defaults_location}/#{defaults_file_name}", defaults_file_name) 
    
    evaluate_defaults_file(defaults_file_name)
  end
  return unless parameters
  @parameter_hash_string = parameters
  raise "parameters: #{parameters.inspect} must be a string which evaluates to a hash" unless parameters.class == String and parameters = eval(parameters) and parameters.class == Hash # parameters.class == String and parameters =~ /\S/
  @parameter_hash = parameters 
  parameters.each do |var, value|
    raise CRFatal.new('Cannot specify id as a parameter') if var.to_sym == :id
    set(var, value) unless value == :default
    next if [:comment, :extra_files].include? var
    @naming_pars.push var
  end
  @naming_pars.uniq!
  self
end

def execute_submission
  if @runner.test_submission
    log 'testing submission'
    eputs info_file
    File.delete(@runner.root_folder + "/submitting")
    exit
  else
    execute
  end
end

# def submit
#   logf(:submit)
#   logi(:@nprocs, @nprocs)
#   
#   raise "Test Submit Error Handling" if @run_test_flags and @run_test_flags[:test_submit_error_handling]
#   
#   eputs "System " + SYS 
#   eputs "nprocs " + @nprocs
# #     puts send(:q)
# 
#   raise CRFatal.new ("Can't find executable: #{executable_location}/#{executable_name}") unless FileTest.exist? File.expand_path("#{executable_location}/#{executable_name}")
# 
#   @naming_pars.each{|par| raise CRFatal.new("@naming_par #{par} is not listed in variables") unless rcp.variables.include? par}
# #   @other_pars = []
# #   @@variables.dup.each do |par, type_co|
# #     @other_pars.push par unless @naming_pars.include? par
# #   end
# 
# #   @dir_name = %[v#@version] + @naming_pars.inject("") do |str, par|
# #     str+="/#{par}_#{send(par)}"
# #   end
# 
#   @dir_name = %[v#@version]
# 
#   @run_name = %[v#@version] + @naming_pars.inject("") do |str, par|
#     str+="_#{par}_#{send(par)}"
#   end
#   @dir_name = @dir_name.gsub(/\s+/, "_") + "/id_#@id"
#   @run_name = @run_name.gsub(/\s+/, "_") + "_id_#@id"
#   @directory = File.expand_path(@dir_name)
# 
#   @job_no = nil
#   qstat = queue_status #|| ""
# #   puts qstat;# gets
# #   qstat = qstat =~ /\S/ ? qstat : nil 
#   if qstat and qstat.class == String
#     FileUtils.makedirs(@dir_name)
#     Dir.chdir(@dir_name) do 
#       generate_input_file
#       job_nos = qstat.scan(/^\s*(\d+)/).map{|match| match[0].to_i} if qstat
# #       logi(:job_nos, job_nos)
#       ##################
#       execute_submission
#       ##################
#       qstat = queue_status #|| ""
# #       qstat = qstat=~/\S/ ? qstat : nil
#       5.times do # job_no may not appear instantly
#         new_job_nos = qstat.scan(/^\s*(\d+)/).map{|match| match[0].to_i}
# #         puts new_job_nos
#         logi(:new_minus_old, new_job_nos-job_nos)
#         @job_no = (new_job_nos-job_nos).sort[-1]
#         break if @job_no
#         sleep 0.2
#         qstat = queue_status
#       end
#       @job_no ||= -1 # some functions don't work if job_no couldn't be found, but most are ok
#       eputs info_file
#       @sys = SYS
#       write_info
#       File.open(".code_runner_version.txt", 'w'){|file| file.puts CODE_RUNNER_VERSION}
#       File.open("code_runner_modlet.rb", 'w'){|file| file.puts rcp.modlet_source} if rcp.modlet_required
#     end
#     
# 
#   else 
#     File.delete("submitting")
#     raise CRFatal.new("queue_status did not return a string; submission cancelled. Suggest editing system_modules/#{SYS}.rb")
#   end
# 
# end

#   Generate the run name and the directory name, and check that the directory is empty. The run name, i.e. @run_name can be set beforehand, in which case it will not be changed. The directory name choice can be influenced by the variable @dir_name, which is not used outside this function.

def prepare_submission(options={})
  raise "Test Submit Error Handling" if @run_test_flags and @run_test_flags[:test_submit_error_handling]
  
  #p '@nprocs', @nprocs
  if @runner
    SUBMIT_OPTIONS.each do |option|
        set(option, @runner.send(option)) if @runner.send(option)
    end
  end
  #p '@nprocs', @nprocs
  
#     puts send(:q)

  raise CRFatal.new ("Can't find executable: #{executable_location}/#{executable_name}") unless FileTest.exist? File.expand_path("#{executable_location}/#{executable_name}")

  @naming_pars.each{|par| raise CRFatal.new("@naming_par #{par} is not listed in variables or run_info") unless (rcp.variables + rcp.run_info).include? par}
  @naming_pars.delete(:g_exb_start_timestep)
  unless @dir_name # dir_name can be set in advance to change the default directory name
    @dir_name = %[v#@version]
    @dir_name = @dir_name.gsub(/\s+/, "_") + "/id_#@id"
  end
  generate_run_name unless @run_name
  
  @directory = File.expand_path(@dir_name)
  #@relative_directory = File.expand_path(Dir.pwd).sub(File.expand_path(@runner.root_folder) + '/', '')
  #@relative_directory = @directory.sub(File.expand_path(@runner.root_folder) + '/', '')
  @relative_directory = @dir_name

  raise "Directory #@dir_name contains code_runner_info" if FileTest.exist? @directory and Dir.entries(@directory).include? ["code_runner_info.rb"]

  @job_no = nil
  FileUtils.makedirs(@dir_name)
  Dir.chdir(@dir_name) do 
    generate_input_file
    copy_extra_files
    
    File.open(".code_runner_version.txt", 'w'){|file| file.puts CODE_RUNNER_VERSION}
    #File.open("code_runner_modlet.rb", 'w'){|file| file.puts rcp.modlet_source} if rcp.modlet_required
  end
  @dir_name = nil

end

#This function copies any files which are required at run time into the run folder.
#It takes the form of an input parameter 'extra_files' which takes in an array
#of file locations and copies them when the run folder is set up. It is called in prepare_submission. 
def copy_extra_files
  if @extra_files.kind_of?String
    @extra_files = [@extra_files]
  end
  if @extra_files.kind_of?Array
    @extra_files.each{|file| 
    FileUtils.cp(file, File.basename(file))}
  end
end

def generate_run_name
  if CodeRunner::GLOBAL_OPTIONS[:short_run_name]
    @run_name = %[v#{@version}_id_#@id]
  else
    @run_name = %[v#@version] + @naming_pars.inject("") do |str, par|
      str+="_#{par}_#{send(par).to_s[0...8]}"
    end
    @run_name = @run_name.gsub(/\s+/, "_").gsub(/\//, '') + "_id_#@id"
  end
end

def write_info
  Dir.chdir(@directory){File.open("code_runner_info.rb", 'w'){|file| file.puts info_file}}
end

# private :write_info

def info_file
    @modlet = rcp.modlet if rcp.modlet?
    return <<EOF
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# #{rcp.code_long} Input Parameters
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Code:     #{rcp.code}
# System:   #{@sys}
# Version:  #{@version}
# Nprocs:   #{@nprocs}
# Directory:  #{Dir.pwd}
# Runname:  #{@run_name}
# ID:   #{@id}
# #{@modlet ? "Modlet:\t#@modlet" : ""} 
# Classname:  #{self.class.to_s}

# #{@job_no ? "Job_No:    #{@job_no}" : ""}

# Parameters:
#{(rcp.variables + rcp.run_info + [:version, :code, :modlet, :sys] - [:component_runs]).inject({}){|hash, var| hash[var] = send(var) unless (!send(var) and send(var) ==  nil); hash}.pretty_inspect}


# Actual Command:
# #{run_command.gsub(/\n/, "\n#")}
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
EOF

end

def set_modlet(modlet, folder=nil)
  logf(:set_modlet)
  rcp.modlet.sub!(/.*/, modlet)
  self.class.set_modlet(modlet, folder)
end
private :set_modlet

def self.set_modlet(modlet, folder = nil)
  raise 'old method -- needs to be debugged'
  Log.log("self.set_modlet", self.to_s)
  class_eval(File.read("#{folder ? folder + "/" : ""}#{modlet}"))
  check_and_update
end

# aliold :inspect
def inspect
  old, @runner = @runner, nil
  str = super
  @runner = old
  str
end


# aliold :pretty_inspect
def pretty_print(q)
  old, @runner = @runner, nil
  str = q.pp_object(self)
  @runner = old
  str

end

#    def pretty_print(q)
#       if /\(Kernel\)#/ !~ Kernel.instance_method(:method).bind(self).call(:inspect).inspect
#         q.text self.inspect
#       elsif /\(Kernel\)#/ !~ Kernel.instance_method(:method).bind(self).call(:to_s).inspect && instance_variables.empty?
#         q.text self.to_s
#       else
#         q.pp_object(self)
#       end
#     end

# A hook for module developers

def self.finish_setting_up_class
end

# ALL = []
# READOUT_LIST = []
# CODE = nil

def self.check_and_update
    Log.logf(:check_and_update)

#   
    finish_setting_up_class
#         ep self.to_s, constants, self.ancestors

#     raise CRFatal.new("Code not defined (#{CODE.inspect}) in class #{self.to_s}") unless CODE and CODE.class == String and CODE =~ /\S/  


    NECESSARY_RUN_SYSTEM_METHODS.each do |method|
      raise CRFatal.new("#{method} not defined in #{SYS}_system_runner.rb") unless instance_methods.include?(method)
    end

    NECESSARY_RUN_CODE_METHODS.each do |method|
      raise CRFatal.new("#{method} not defined in #{self.class}_code_runner.rb") unless instance_methods.include?(method)
    end
  
    
    NECESSARY_RUN_CLASS_PROPERTIES.each do |v,class_list|
#       raise CRFatal.new("#{v} not defined") unless rcp[v]
      raise CRFatal.new("#{v} not defined correctly: class is #{rcp[v].class} instead of one of #{class_list.to_s}") unless class_list.include? rcp[v].class
    end
    
    @readout_list = (rcp.variables+rcp.results) unless rcp.readout_list?

    raise "

Please add the line 

-----------------------------------------------------------
@code_module_folder = folder = File.dirname(File.expand_path(__FILE__)) # i.e. the directory this file is in
---------------------------------------------------------

to your code module.
    
    " unless rcp.code_module_folder?

#     (variables+results).each{|v| const_get(:READOUT_LIST).push v} unless READOUT_LIST.size > 0

    #if rcp.variables_0_5_0
      #rcp.variables_0_5_0.dup.each do |par, info| #for backwards compatibility only
        #rcp.variables_0_5_0[par] = info[0] if info.class == Array
      #end
    #end





#     Log.log(:@@variables0, @@variables[0])

    @run_info = rcp.run_info || [] # Run info can optionally be defined in the code module.
#     ep @run_info
    @run_info = rcp.run_info + ([:preamble, :job_no, :running, :id, :status, :sys, :is_component, :naming_pars, :run_name, :resubmit_id, :real_id, :component_runs, :parameter_hash, :parameter_hash_string, :output_file, :error_file, :extra_files, :code_run_environment] + SUBMIT_OPTIONS) #.each{|v| RUN_INFO.push v} unless RUN_INFO.include? :job_no
    @all = (rcp.variables + rcp.results + rcp.run_info) #.each{|v| ALL.push v}
#     ep "GOT HERE"
    (@all + [:directory, :run_name, :modlet, :relative_directory]).each{|var| send(:attr_accessor, var)}
    #eputs "Checking and updating"
    @user_defaults_location = ENV['HOME'] + "/.coderunner/#{rcp.code}crmod/defaults_files"
    #eputs ' user_defaults_location', rcp.user_defaults_location
    define_method(:output_file) do 
      return @output_file if @output_file
      @output_file = super()
    end
    define_method(:error_file) do 
      return @error_file if @error_file
      @error_file = super()
    end

    Dir.chdir(SCRIPT_FOLDER + "/system_modules") do 
    @system_run_classes ||=   
      Dir.entries(Dir.pwd).find_all{|file| file =~ /^[^\.].+\.rb$/}.inject([]) do |arr, file|
        #p Dir.pwd
        #p 'required', file, Dir.pwd
        require Dir.pwd + '/' + file
#         p CodeRunner.constants
        sys = file.sub(/\.rb$/, '')
        arr.push(add_a_child_class("#{sys.variable_to_class_name}Run"))
        arr[-1].send(:include, CodeRunner.const_get(sys.variable_to_class_name))
        arr
      end
    end

    
end

def dup
  return self.class.new(@runner).learn_from(self)
end

def create_component
  @component_runs ||= []
  new_run = dup
  new_run.is_component = true
  new_run.real_id = @id
  @runner.add_component_run(new_run)
  @component_runs.push new_run
  new_run
end

def learn_from(run)
  run.instance_variables.each do |var|  
#       puts var
#     puts run.instance_variable_get(var)
      instance_variable_set(var,run.instance_variable_get(var)) 
#         puts instance_variable_get(var)

#     rescue NoMethodError
#       next
#     end
  end
  self
end



    
def logiv
  instance_variables.each do |var|
    unless var == :@runner or var == :@system_triers
      log(var); logi(instance_variable_get(var))
    end
  end
end

def recheck
  logf(:recheck)
  Dir.chdir(@directory) do
#     puts 'ackack'
    puts "Rechecking #@run_name"
    #runner = @runner
    instance_variables.each{|var| instance_variable_set(var, nil) unless var == :@runner}
    begin File.delete("CODE_RUNNER_RUN_DATA") rescue Errno::ENOENT end
    begin File.delete("CODE_RUNNER_RESULTS") rescue Errno::ENOENT end
    process_directory
    save
  end
end

def generate_component_runs
end
  
def generate_combined_ids(type)
  raise CRFatal.new("Can't call generate_combined_ids from a run")
end

# @@maxes = {}
# @@cmaxes = {}

def max(variable, complete=false) #does this run have the maximum value of this variable
  raise ArgumentError.new("complete must be true or false") unless [TrueClass, FalseClass].include? complete.class
  @runner.generate_combined_ids
  ids = @runner.combined_ids 
  if complete
    ids = ids.find_all{|id| @runner.combined_run_list[id].status == :Complete}
    max_id = @runner.cmaxes[variable] ||= ids.sort_by{|id| @runner.combined_run_list[id].send(variable)}[-1]
  else
    max_id = @runner.maxes[variable] ||= ids.sort_by{|id| @runner.combined_run_list[id].send(variable)}[-1]
  end
  return @runner.combined_run_list[max_id].send(variable) == send(variable)
end

# # @@mins = {}
# @@cmins = {}


def min(variable, complete=false) #does this run have the minimum value of this variable
  raise ArgumentError.new("complete must be true or false") unless [TrueClass, FalseClass].include? complete.class
  @runner.generate_combined_ids
  ids = @runner.combined_ids 
  
  if complete
    ids = ids.find_all{|id| @runner.combined_run_list[id].status == :Complete}
    min_id = @runner.cmins[variable] ||= ids.sort_by{|id| @runner.combined_run_list[id].send(variable)}[0]
  else
    min_id = @runner.mins[variable] ||= ids.sort_by{|id| @runner.combined_run_list[id].send(variable)}[0]
  end
  return @runner.combined_run_list[min_id].send(variable) == send(variable)
end

# @@fmaxes = {}
# @@cfmaxes = {}

# # Does this run have the maximum value of this variable to be found amoung the filtered runs?
# 
# def fmax(variable, complete = false) 
#   raise ArgumentError.new("complete must be true or false") unless [TrueClass, FalseClass].include complete.class
#   @runner.generate_combined_ids
#   ids = @runner.filtered_ids # o^o-¬
#   if complete
#     ids = ids.find_all{|id| @runner.combined_run_list[id].status == :Complete}
#     max_id = @@cfmaxes[variable] ||= ids.sort_by{|id| @runner.combined_run_list[id].send(variable)}[-1]
#   else
#     max_id = @@fmaxes[variable] ||= ids.sort_by{|id| @runner.combined_run_list[id].send(variable)}[-1]
#   end
#   return @runner.combined_run_list[max_id].send(variable) == send(variable)
# end
# 

def smax(variable,sweep=nil, complete=nil)
  logf(:max)
  sweep ||= variable
  if complete
    @csmaxes[variable] ||= {}
    max_id = @csmaxes[variable][sweep] = @runner.get_max(self, variable,sweep, complete)
  else
    @smaxes[variable] ||= {}
    max_id = @smaxes[variable][sweep] = @runner.get_max(self, variable,sweep, complete)
  end
  return @runner.combined_run_list[max_id].send(variable) == send(variable)
end

def smin(variable,sweep=nil, complete=nil)
  logf(:min)
  sweep ||= variable
  @smins ||= {}
  @csmins ||= {}
  if complete
    @csmins[variable] ||= {}
    min_id = @csmins[variable][sweep] = @runner.get_min(self, variable,sweep, complete)
  else
    @smins[variable] ||= {}
    min_id = @smins[variable][sweep] = @runner.get_min(self, variable,sweep, complete)
  end
  return @runner.combined_run_list[min_id].send(variable) == send(variable)
end

# aliold :_dump
# def _dump(*args)
#   @runner, runner = nil, @runner
#   ans = super(*args)
#   @runner = runner
#   return ans
# end

def executable_name
  File.basename(@executable||=@runner.executable)
end

def executable_location
  @executable||=@runner.executable
  raise "No executable" unless @executable
  File.dirname(@executable)
end

def update_in_queue
  unless @status == :Queueing
    raise 'Can only updated runs whose status is :Queueing'
  end
  unless methods.include? :batch_script_file
    raise 'Can only update runs which have been submitted using a batch script file'
  end 
  old_run_name = @run_name
  generate_run_name
  new_run_name = @run_name
  #@run_name = old_run_name
  unless FileTest.exist?(filename = @directory + '/' + batch_script_file) or 
    FileTest.exist?(filename =  @runner.root_folder + '/' + batch_script_file)
      raise 'Could not find batch_script_file'
  end
  old_batch_script=File.read(filename)
  eputs old_batch_script
eputs old_batch_script.gsub(Regexp.new(Regexp.escape(old_run_name)), new_run_name)
  ep Regexp.new(Regexp.escape(old_run_name))
  File.open(filename, 'w'){|file| file.puts old_batch_script.gsub(Regexp.new(Regexp.escape(old_run_name)), new_run_name)}

  
  generate_input_file
  #throw(:done)
  write_info
end

  # A hook... default is to do nothing

  def self.modify_job_script(runner, runs, script)
    return script
  end 

  # A hook... a string which gets put into the job
  # script. Used to load modules, configure the run 
  # time environment for a given code. Default
  # is to return an empty string.

  def code_run_environment
    @code_run_environment
  end

# Prints a warning message, useful for pre-submit checks.
def warning(message)
  eputs "Warning: " + message; sleep 0.1
end

def info(message)
  eputs "Info: " + message; sleep 0.02
end

class SubmitError < StandardError
end

# Prints an error message and raises a SubmitError, useful for pre-submit checks.
def error(message)
  raise("Error: " + message)
end

# Returns the number of nodes times the number of cores, assuming the processor 
# layout is specified as either cores, nodesxcores, or nodesxcoresxthreads
def actual_number_of_processors
    raise "Please specify the processor layout using the -n or (n:) option" unless @nprocs
      @nprocs.split('x').slice(0..1).map{|n| n.to_i}.inject(1){|ntot, n| ntot*n}
end

def latex_report_header
#gsub is a hack which removes 14 spaces from the beginning of the file. This allows nice code indentation here.
<<-EOF.gsub(/^ {4}/, "")
    % Set up  
    \\documentclass[11pt, twocolumn]{report}
    \\usepackage{amsmath}
    \\usepackage{amsthm}
    \\usepackage{amssymb}
    \\usepackage{graphicx}
    \\usepackage{caption}
    \\usepackage{subcaption}
    \\usepackage{wrapfig}
    \\usepackage{epstopdf}
    \\usepackage{fullpage}

    \\newcommand{\\newfig}[1]{
    \\includegraphics[width=\\linewidth]{#1}
    }

    \\begin{document}

    % Title Page
    \\title{Run summary for run number #{id}}
    \\date{#{Time.now}}
    \\author{CodeRunner}
                  
    \\maketitle

EOF

end

end

end
