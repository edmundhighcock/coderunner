
$stderr.puts "CodeRunner (c) 2009-2016. Written by Edmund Highcock & Ferdinand van Wyk. Loading..." unless $has_put_startup_message_for_code_runner

if RUBY_VERSION.to_f < 1.9
  raise "Ruby version 1.9 or greater required (current version is #{RUBY_VERSION})"
end


require 'rubygems'
require "rubyhacks"

# Basic class setup
require 'coderunner/config'


$JCODE = 'U'


#########################################
#       Load Libraries                  #
#########################################


$stderr.print 'Loading libraries...' unless $has_put_startup_message_for_code_runner

#################################
#read this if you are puzzled by
# some non-standard use of ruby
################################
#require CodeRunner::SCRIPT_FOLDER + "/box_of_tricks.rb"
################################

require "getoptlong"
require "thread"
require "fileutils"
require "drb"
#require "test/unit/assertions"
require 'parallelpipes'
require 'find'

begin
  require 'hostmanager'
rescue LoadError
  eprint 'no hostmanager.'
end

begin
  require "rubygems"
  require "rbgsl"
  require "gsl_extras"
  #require CodeRunner::SCRIPT_FOLDER + "/gsl_tools.rb"
rescue LoadError
  $stderr.puts "Warning: could not load rbgsl; limited functionality"
end

#require CodeRunner::SCRIPT_FOLDER + "/gnuplot.rb"
require "graphkit"
CodeRunner::GraphKit = GraphKit # Backwards compatibility

# load 'gnuplot'
load CodeRunner::SCRIPT_FOLDER + "/feedback.rb"
eprint '.' unless $has_put_startup_message_for_code_runner
load CodeRunner::SCRIPT_FOLDER + "/test.rb"
eprint '.' unless $has_put_startup_message_for_code_runner
#load CodeRunner::SCRIPT_FOLDER + "/input_file_generator.rb"
#eprint '.' unless $has_put_startup_message_for_code_runner
load CodeRunner::SCRIPT_FOLDER + "/long_regexen.rb"
eprint '.' unless $has_put_startup_message_for_code_runner
load CodeRunner::SCRIPT_FOLDER + "/heuristic_run_methods.rb"
eprint '.' unless $has_put_startup_message_for_code_runner
#load CodeRunner::SCRIPT_FOLDER + "/code_runner_version.rb"
#eprint '.' unless $has_put_startup_message_for_code_runner
load CodeRunner::SCRIPT_FOLDER + "/fortran_namelist.rb"
eprint '.' unless $has_put_startup_message_for_code_runner
load CodeRunner::SCRIPT_FOLDER + "/fortran_namelist_c.rb"
eprint '.' unless $has_put_startup_message_for_code_runner
load CodeRunner::SCRIPT_FOLDER + "/repository.rb"
eprint '.' unless $has_put_startup_message_for_code_runner


CodeRunner::GLOBAL_BINDING = binding


Log.log_file = nil




class CodeRunner

  ####################################
  # Commmand line processing         #
  ####################################


  # Here are all the methods that map the command line invocation into the correct class method call
  COMMAND_LINE_FLAGS_WITH_HELP = [
    ["--recalc-all", "-A", GetoptLong::NO_ARGUMENT, %[Causes each directory to be reprocessed, rather than reading the cache of data. Its exact effect depends on the code module being used. By convention it implies that ALL data analysis will be redone.]],
    ["--reprocess-all", "-a", GetoptLong::NO_ARGUMENT, %[Causes each directory to be reprocessed, rather than reading the cache of data. Its exact effect depends on the code module being used. By convention it implies that VERY LITTLE data analysis will be redone.]],
    ["--code", "-C", GetoptLong::REQUIRED_ARGUMENT, %[The code that is being used for simulations in this folder. This string must correspond to a code module supplied to CodeRunner. It usually only needs to be specified once as it will be stored as a default in the folder.]],
    ["--comment", "-c", GetoptLong::REQUIRED_ARGUMENT, %[A comment about the submitted run.]],
    ["--debug", "-d", GetoptLong::NO_ARGUMENT, %[Submit the simulation to the debug queue. This usually only has meaning on HPC systems. It does not mean debug CodeRunner!]],
    ["--defaults-file", "-D", GetoptLong::REQUIRED_ARGUMENT, %[Specify a defaults file to be used when submitting runs. The name should correspond to file named something like '<name>_defaults.rb' in the correct folders within the code module. Every time a different defaults file is specified, a local copy of that defaults file is stored in the root folder. This local copy can be edited and all runs will use the local copy to get defaults. CodeRunner will never overwrite the local copy.]],
    ["--film-options", "-F", GetoptLong::OPTIONAL_ARGUMENT, %[Specify a hash of options when making films. The most important one is fa (frame array). For example  -F '{fa: [0, 200]}'. For all possible options see the CodeRunner method make_film_from_lists.]],
    ["--conditions", "-f", GetoptLong::REQUIRED_ARGUMENT, %[A string specifying conditions used to filter runs. This filter is used in a variety of circumstances, for example when printing out the status, plotting graphs etc. Example: '@height == 10 and @width = 2.2 and @status==:Complete'.]],
    ["--run-graph", "-g", GetoptLong::REQUIRED_ARGUMENT, %[Specify a run_graphkit to plot. A run_graphkit is one that is plotted for an individual run. The run graphkits available depend on the code module. The syntax is graphkit shorthand:\n       -g '<graph_name>[ ; <graph_options> [ ; <conditions> [ ; <sort> ] ] ]'\n where conditions (i.e. filter) and sort will override the -f and -O flags respectively. The -g flag can be specified multiple times, which will plot multiple graphs on the same page.]],
    ["--graph", "-G", GetoptLong::REQUIRED_ARGUMENT, %[Specify a graphkit to plot. A graphkit combines data for every filtered run. The syntax is graphkit shorthand:\n        -G '<axis1>[ : <axis2> [ : <axis3 [ : <axis4> ] ] ] [ ; <graph_options> [ ; <conditions> [ ; <sort> ] ] ]'\n        where conditions (i.e. filter) and sort will override the -f and -O flags respectively. <axis1> etc are strings which can be evaluated by the runs. The -G flag can be specified multiple times, which will plot multiple graphs on the same page. For example\n                   -G 'width : 2*height ; {} ; depth == 2 ; width'\n          will plot twice the height against the width for every run where the depth is equal to 2, and will order the data points by width.]],
    ["--heuristic-analysis", "-H", GetoptLong::NO_ARGUMENT, %[Should be specified whenever CodeRunner is being used to analyse simulations which did not originally submit (and which will therefore not have the usual CodeRunner meta data stored with them).] ],
    ["--use-component", "-h", GetoptLong::OPTIONAL_ARGUMENT, %[Specify whether to use real or component runs]],
    ["--just", "-j",  GetoptLong::REQUIRED_ARGUMENT, %[Specify individual run ids. For example -j 45,63,128 is shorthand for -f 'id==45 or id==63 or id==128']],
    ["--job_chain", "-J",  GetoptLong::NO_ARGUMENT, %[Chain multiple simulations into one batch/submission job. Most useful for HPC systems.]],
    ["--skip-similar-jobs-off", "-k", GetoptLong::NO_ARGUMENT, %[Normally CodeRunner will not submit a run whose input parameters identical to a previous run (to avoid wasting computer time). Specifying the flag will override that behaviour and force submission of an identical run.]],
    ["--loop", "-l", GetoptLong::NO_ARGUMENT, %[Used with the status command. Keep continually printing out live status information.]],
    ["--multiple-processes", "-M", GetoptLong::REQUIRED_ARGUMENT],
    ["--modlet", "-m", GetoptLong::REQUIRED_ARGUMENT, %[Specify the modlet to be used in the current folder. Only needs to be specified once as it will be stored as a default.]],
    ["--no-run", "-N", GetoptLong::NO_ARGUMENT, %[On some machines getting a list of currently running jobs takes a long time. Specifying this flag tells CodeRunner that you definitely know that no runs in the folder are still queueing or running. Do not specify it if there are still running jobs as it will cause their statuses to be updated incorrectly.]],
    ["--nprocs", "-n", GetoptLong::REQUIRED_ARGUMENT, %[A string specifying the processor layout for the simulation. For example -n 46x4 means use 46 nodes with four processors per node. In the case of a personal computer something like -n 2 is more likely. The default is 1]],
    ["--sort", "-O", GetoptLong::REQUIRED_ARGUMENT, %[Specify the sort order for the runs. Used for a variety of commands, for example status. It is a string of semicolon separated sort keys: for example -O height;width will sort the runs by height and then width.]],
    ["--project", "-P", GetoptLong::REQUIRED_ARGUMENT, %[Specify the project to be used for billing purposes. Only necessary on some systems.]],
    ["--parameters", "-p",  GetoptLong::REQUIRED_ARGUMENT, %[A hash of parameters for the simulation. For example -p '{height: 20, width: 2.3}'. These parameters will override the defaults in the local defaults file.]],
    ["--queue", "-Q", GetoptLong::REQUIRED_ARGUMENT, %[The name of the queue to submit to on HPC systems. Not yet implemented for all systems. Please submit a feature request if it is not working on your system.]],
    ["--no-auto-create-runner", "-q", GetoptLong::NO_ARGUMENT, %[Used for interactive mode when you don't want CodeRunner to analyse the current directory.]],
    ["--terminal-size", "-t", GetoptLong::REQUIRED_ARGUMENT, %[Specify the terminal size for situations where CodeRunner cannot work it out:  -t '[rows, cols]' (square brackets are part of the syntax)]],
    ["--test-submission", "-T", GetoptLong::NO_ARGUMENT, %[Don't actually submit the run, but exit after printing out the run parameters and generating any input files necessary.]],
    ["--use-large-cache-but-recheck-incomplete", "-u", GetoptLong::NO_ARGUMENT, %[Use the large cache for speed, but check any runs whose status is not :Complete or :Failed.]],
    ["--use-large-cache", "-U", GetoptLong::NO_ARGUMENT, %[Use the large cache for speed. No run data will be updated.]],
    ["--version", "-v", GetoptLong::REQUIRED_ARGUMENT, %[Specify the version of the simulation code being used. Only has an effect for certain code modules.]],
    ["--wall-mins", "-W", GetoptLong::REQUIRED_ARGUMENT, %[Specify the wall clock limit in minutes.]],
    ["--write-options", "-w", GetoptLong::REQUIRED_ARGUMENT, %[Use when plotting graphs. A hash of custom options which are applied to the graphkit just before plotting it; for example: -w '{xlabel: 'X Axis Quantity, log_axis: 'y'}']],
    ["--executable", "-X", GetoptLong::REQUIRED_ARGUMENT, %[Specify the location of the executable of the simulation code. It only needs to be specified once in any folder, unless it needs to be changed.]],
    ["--other-folder", "-Y", GetoptLong::REQUIRED_ARGUMENT, %[Run CodeRunner in a different folder. On a local machine 'coderunner st -Y some/other/folder' is identical to 'cd some/other/folder; coderunner st -Y'. However, this flag can also be used for remote folders using RemoteCodeRunner (as long as CodeRunner is installed on the remote machine). e.g. -Y username@machine.location:path/to/folder. If this option is specified multiple times, a merged runner will be created from the set of specified folders.]],
    ["--supplementary-options", "-y", GetoptLong::REQUIRED_ARGUMENT],
    ["--server", "-Z", GetoptLong::REQUIRED_ARGUMENT, %[Technical use only]],
    ["--log", "-z", GetoptLong::NO_ARGUMENT, %[Switch logging on (currently not working very well (05/2010)).]]  # :nodoc:
  ]

  CLF = COMMAND_LINE_FLAGS = COMMAND_LINE_FLAGS_WITH_HELP.map{|arr| arr.slice(0..2)}

  CODE_COMMAND_OPTIONS = [] # NEEDS FIXING!!!!
  #(Dir.entries(SCRIPT_FOLDER + "/code_modules/") - [".", "..", ".svn"]).map do |d|
  #["--#{d}-options", "", GetoptLong::REQUIRED_ARGUMENT, %[A hash of options for the #{d} code module]]
  #end

  LONG_COMMAND_LINE_OPTIONS = [
    ["--replace-existing", "", GetoptLong::NO_ARGUMENT, %[Use with resubmit: causes each resubmitted run to replace the run being resubmitted.]],
    ["--smart-resubmit-name", "", GetoptLong::NO_ARGUMENT, %[Use with resubmit: causes each resubmitted run to only contain its original id and changed parameters in its run name.]],
    ["--submit-runner-index", "", GetoptLong::NO_ARGUMENT, %[Use with submit or resubmit when specifying multiple root folders... selects which runner will be used for submitting (i.e. which root folder the runs will be submitted in.]],
  ] + CODE_COMMAND_OPTIONS
  LONG_COMMAND_LINE_FLAGS = LONG_COMMAND_LINE_OPTIONS.map{|arr| [arr[0], arr[2]]}

  rihelp  = <<EOF
Documents classes, methods, constants and modules in the usual Ruby form: e.g.

* CodeRunner   -- a class
* CodeRunner.status -- a class method
* CodeRunner#filter  -- an instance method
* CodeRunner::Run -- a sub class
* CodeRunner::CODE_RUNNER_VERSION --a constant
EOF


  COMMANDS_WITH_HELP = [
    ["available_modlets", "av", 0, 'List the available modlets for the code module.', [], [:C]],
    ["available_defaults_files", "avd", 0, 'List the defaults files for the code module.', [], [:C]],
    ["cancel", "can", 0, 'Cancel the specified job.', [], [:j, :f, :U, :N]],
    ["change_run_id", "cri", 1, 'Changes the id of a given set of runs to a new set of ids', ['new_ids'], [:j, :f, :U, :N]],
    ["code_command", "cc", 1, 'Call a class method of the run class. Effectively this will call run_class.class_eval(command). See documentation for whichever code module is in use.', ['command'], []],
    ["concat", "concat", 1, 'Concatenates NetCDF output files together. File is output in the CR root directory.', ['output file'], [:j, :f, :U, :N]],
    ["continue_in_new_folder", "cnf", 1, 'Make a new folder in the parent directory and copy all coderunner configuration files to that folder. If options j or f are specified, copy all matching runs to that new folder.', ['folder'], [:j, :f, :U, :N]],
    ["code_runner_execute", "crex",  1, 'Run (within the CodeRunner class) the fragment of Ruby code given.', ['Ruby fragment'], []],
    ["delete", "del", 0, 'Permanently erase all filtered runs.', [], [:j, :F, :U, :N]],
    ["differences_between", "diff", 0, 'Print a table of all the differences between the input parameters of the filtered ids.', [], [:j, :f, :U, :N]],
    ["directory", "dir", 1, 'Print out the directory for the given run.', ['id'], []],
    ['dumb_film', "dfm", 0, 'Create a film of the specified graphkits using gnuplot "dumb" ASCII terminal.', [], [:F, :G, :g, :U, :N, :j, :f]],
    ["execute", "ex",  1, 'Run (at the top level) the fragment of Ruby code given.', ['Ruby fragment'], []],
    ['film', "fm", 0, 'Create a film of the specified graphkits.', [], [:F, :G, :g, :U, :N, :j, :f]],
    ["generate_modlet_from_input_file", "gm", 1, 'Deprecated', [], []],
    ["generate_cubecalc", "gencc", 0, 'Generate the file cubecalc.cc, the source code for the coderunner test program.', [], []],
    ["generate_documentation", "rdoc", 1, 'Create automatic documentation using the rdoc tool (deprecated, use the command line tool ri for getting help, or see rubygems.org/gems/coderunner).', [], []],
    ["interactive_mode", "im", 0, 'Launch an interactive terminal. Any command line flags specified set the defaults for the session.', [], [:U, :N, :j, :q]],
    ["load_file", "ld",  1, 'Load a Ruby script file using the CodeRunner framework.', ['script file'], []],
    ['manual', 'man', 0, 'Print out command line manual', [], []],
    ['netcdf_plot', 'ncplot', 3, 'Plot a comma separated list of variables, at a comma separated list of indices (nil for all) from the specified netcdf file against each other using gnuplot.', ['netcdf_file', 'vars', 'indices'], [:w]],
    ["plot_graph", "plot", 0, 'Plot the specified graphkits using Gnuplot', [], [:G, :g, :w, :O, :U, :N, :j, :f]],
    ["parameter_scan", "ps", 1, 'Read a parameter scan from file. For full details of how to write a parameter scan, see online documentation (coderunner.sourceforge.net).', ['scan file'], [:n, :W, :k, :v, :p, :T, :d]],
    ['print_queue_status', 'qstat', 0, 'Show the current status of the queue', [], [:U, :u]],
    ["readout", "ro", 0, 'Print a simple text readout of all data from the runs.', [], []],
    ["reference", "ri", 1, "Print out documentation for the given class or method. #{rihelp}", ['ruby_class_or_method'], []],
    ["resubmit", "resub", 0, 'Resubmit the filtered runs to be simulated. All parameters will be the same bar those altered by the p option.', [], [:p, :n, :W, :k, :v, :T, :d, :J, :f, :j]],
      ["run_command", "rc", 1, 'Cause all filtered runs to evaluate the given string.', ['command string'], [:U, :f, :j, :N]],
      ["runner_eval", "ev", 1, 'Cause the runner (the CodeRunner instance) to evaluate the given string.', ['command string'], [:U, :N, :j, :f]],
      ["scan", "scan", 1, 'Submit a simple scan. For full details of how to write a simple scan, see online documentation (coderunner.sourceforge.net).', ['scan string'],  [:p, :n, :W, :k, :v, :T, :d]],
      ["show_values_of", "shvl", 1, 'Evaluate the expression for each run and print a unique sorted list of them.', ['expression'],  [:U, :N, :j, :f]],
      ['start_launcher', 'launch', 2, 'Start a simple job launcher for non batch systems.', ['refresh_interval', 'max_queue_size'], []],
      ["status", "st", 0, 'Print out a summary of the status of the filtered runs.', [], [:U, :N, :j, :f, :O]],
      ["status_with_comments", "sc", 0, 'Print a list of ids with their status and any comments.', [], [:U, :N, :j, :f, :O]],
      ["status_loop", "sl", 0, 'Loop, updating the filtered runs, then printing out a summary of the status of the filtered runs.  ', [], [:U, :N, :j, :f, :O]],
      ["status_loop_running", "slr", 0, 'Loop, updating and then printing out a summary of runs which are currently running.', [], [:U, :N, :O]],
      ["submit", "sub", 0, 'Submit a run to be simulated.', [], [:p, :n, :W, :k, :v, :T, :d, :J]],
      ["submit_command", "subcom", 2, 'Submit an arbitrary shell command to the batch queue.', ['job name', 'command'], [:n, :W, :v, :T, :d]],
      ["write_graph", "wg", 1, 'Write a graph to disk.', ['filename'], [:G, :g, :w, :O, :U, :N, :j, :f]],
      ["write_report", "wr", 0, 'Writes out a summary of a given run in a LaTeX document.', [], [:j, :f, :U, :N]],
  ]

  # This lists all the commands available on the command line. The first two items in each array indicate the long and short form of the command, and the third indicates the number of arguments the command takes. They are all implemented as Code Runner class methods (the method is named after the long form). The short form of the command is available as a global method in Code Runner interactive mode.

  COMMANDS = COMMANDS_WITH_HELP.map{|arr| arr.slice(0..2)}

  # A lookup hash which gives the appropriate short command option (copt) key for a given long command flag

  CLF_TO_SHORT_COPTS = COMMAND_LINE_FLAGS.inject({}){ |hash, (long, short, _req)|
    letter = short[1,1]
    hash[long] = letter.to_sym
    hash
  }

  # specifying flag sets a bool to be true

  CLF_BOOLS = [:H, :U, :u, :A, :a, :T, :N, :q, :z, :d, :J, :replace_existing]
  #     CLF_BOOLS = [:s, :r, :D, :H, :U, :u, :L, :l, :A, :a, :T, :N,:V, :q, :z, :d] #

  CLF_INVERSE_BOOLS = [:k] # specifying flag sets a bool to be false

  # a look up hash that converts the long form of the command options to the short form (NB command options e.g. use_large_cache have a different form from command line flags e.g. --use-large-cache)

  LONG_TO_SHORT = COMMAND_LINE_FLAGS.inject({}){ |hash, (long, short, _req)|
    letter = short[1,1]
    hash[long[2, long.size].gsub(/\-/, '_').to_sym] = letter.to_sym
    hash
  }

  # A look up table that converts long only command line options (in LONG_COMMAND_LINE_OPTIONS) to the equivalent CodeRunner command option

  CLF_TO_LONG = LONG_COMMAND_LINE_OPTIONS.inject({}) do |hash, (long, _short, _req, _help)|
    option = long[2, long.size].gsub(/\-/, '_').to_sym
    hash[long] = option
    hash
  end

  #Converts a command line flag opt with value arg to a command option which is stored in copts

  def self.process_command_line_option(opt, arg, copts)
    case opt
    when "--change-directory"
      copts[:c] = arg.to_i
    when "--delete"
      copts[:x] = arg.to_i
    when "--graph"
      copts[:G].push arg
    when "--run-graph"
      copts[:g].push arg
    when "--other-folder"
      if copts[:Y]
        if copts[:Y].kind_of? String
          copts[:Y] = [copts[:Y], arg]
        else
          copts[:Y].push arg
        end
      else
        copts[:Y] = arg
      end
      #     when "--cancel"
      #       copts[:K] = arg.to_i
    when "--multiple-processes"
      copts[:M] = arg.to_i
    when "--film"
      copts[:F] = (arg or true)
    when "--recheck"
      copts[:R] = arg.to_i
    when "--use-large-cache-but-recheck-incomplete"
      copts[:U] = true
      copts[:u]=true
    when "--wall-mins"
      copts[:W] = arg.to_i
    when "--use-component"
      copts[:h] = (arg and arg =~ /\S/) ? arg.to_sym : :component
    when "--terminal-size"
      array = eval arg
      ENV['ROWS'], ENV['COLS'] = array[0].to_s, array[1].to_s
    when "--interactive-mode"
      @@interactive_mode = true
    when "--parameters"
      copts[:p].push arg
    else
      if CLF_BOOLS.include? CLF_TO_SHORT_COPTS[opt]
        copts[CLF_TO_SHORT_COPTS[opt]] = true
      elsif CLF_INVERSE_BOOLS.include? CLF_TO_SHORT_COPTS[opt]
        copts[CLF_TO_SHORT_COPTS[opt]] = false
      elsif CLF_TO_SHORT_COPTS[opt] # Applies to most options
        copts[CLF_TO_SHORT_COPTS[opt]] = arg
      elsif CLF_BOOLS.include? CLF_TO_LONG[opt]
        copts[CLF_TO_LONG[opt]] = true
      elsif CLF_INVERSE_BOOLS.include? CLF_TO_LONG[opt]
        copts[CLF_TO_LONG[opt]] = false
      elsif CODE_COMMAND_OPTIONS.map{|o| o[0]}.include? opt
        begin
          #copts[:code_copts] ||= {}
          copts[
            #CLF_TO_LONG[opt].to_s.sub('_options','').to_sym
            CLF_TO_LONG[opt]
          ] = eval(arg)
        rescue SyntaxError => err
          eputs "\nOption #{opt} must be a hash\n\n"
          raise err
        end

      elsif CLF_TO_LONG[opt]
        copts[CLF_TO_LONG[opt]] = arg
      else
        raise "Unknown command line argument: #{opt}"
      end
    end
    copts
  end

  # Default command options; they are usually determined by the command line flags, but can be set independently

  DEFAULT_COMMAND_OPTIONS = {}

  def self.set_default_command_options_from_command_line

    #some defaults
    #     DEFAULT_COMMAND_OPTIONS[:p] ||= {}
    DEFAULT_COMMAND_OPTIONS[:v] ||= ""
    #DEFAULT_COMMAND_OPTIONS[:n] ||= "1"
    DEFAULT_COMMAND_OPTIONS[:G] = []
    DEFAULT_COMMAND_OPTIONS[:g] = []
    DEFAULT_COMMAND_OPTIONS[:k] = true
    DEFAULT_COMMAND_OPTIONS[:h] ||= :real
    DEFAULT_COMMAND_OPTIONS[:p] = []

    #     ep COMMAND_LINE_FLAGS
    opts = GetoptLong.new(*(COMMAND_LINE_FLAGS + LONG_COMMAND_LINE_FLAGS))
    opts.each do |opt, arg|
      process_command_line_option(opt, arg, DEFAULT_COMMAND_OPTIONS)
    end
    #raise "\n\nCannot use large cache ('-U' or '-u' ) if submitting runs" if DEFAULT_COMMAND_OPTIONS[:U] and (DEFAULT_COMMAND_OPTIONS[:s] or DEFAULT_COMMAND_OPTIONS[:P])


    if DEFAULT_COMMAND_OPTIONS[:z]
      Log.log_file = Dir.pwd + '/.cr_logfile.txt'
      Log.clean_up
    else
      Log.log_file = nil
      # puts Log.log_file
    end
  end

  def self.run_script
    set_default_command_options_from_command_line
    if DEFAULT_COMMAND_OPTIONS[:Z]
      DEFAULT_COMMAND_OPTIONS.absorb(eval(DEFAULT_COMMAND_OPTIONS[:Z]))
      puts "Begin Output"
    end
    command = COMMANDS.find{|com| com.slice(0..1).include? ARGV[0]}
    raise "\n-------------------\nCommand #{ARGV[0].inspect} not found: try 'coderunner man' for help\n-------------------\n" unless command
    send(command[0].to_sym, *ARGV.values_at(*(1...(1+command[2])).to_a))
  end


end


load CodeRunner::SCRIPT_FOLDER + "/class_methods.rb"
load CodeRunner::SCRIPT_FOLDER + "/instance_methods.rb"
load CodeRunner::SCRIPT_FOLDER + "/interactive_methods.rb"
$stderr.puts unless $has_put_startup_message_for_code_runner
$has_put_startup_message_for_code_runner = true


#CodeRunner.set_default_command_options_from_command_line

do_profile = (ENV['CODE_RUNNER_PROFILE'] and ENV['CODE_RUNNER_PROFILE'].size > 0) ?  ENV['CODE_RUNNER_PROFILE'] : false




if do_profile
  begin
    require 'ruby-prof'
  rescue LoadError
    eputs "Please install ruby-prof using ' $ gem install ruby-prof'"
    exit
  end

  # Profile the code
  RubyProf.start
end
####################
CodeRunner.run_script if $0 == __FILE__
###################

if do_profile
  result = RubyProf.stop

  # Print a flat profile to text
  case ENV['CODE_RUNNER_PROFILE']
  when /html/i
    printer = RubyProf::GraphHtmlPrinter.new(result)
  when /graph/i
    printer = RubyProf::GraphPrinter.new(result)
  when /txt/i
    printer = RubyProf::FlatPrinter.new(result)
  else
    raise "CODE_RUNNER_PROFILE should be 'html', 'graph' or 'txt'"
  end

  printer.print($stdout, {})
end
