class CodeRunner

  # In the next section are the implementations of all the standard Code Runner commands and some helper functions.

  def self.set_runner_defaults(copts = {})
      (DEFAULT_RUNNER_OPTIONS.keys - [:sys, :script_folder]).each do |var|
      DEFAULT_RUNNER_OPTIONS[var] =  copts[LONG_TO_SHORT[var]]
    end
    set_class_defaults(copts)
#     ep DEFAULT_RUNNER_OPTIONS
  end

  def self.set_class_defaults(copts={})
    (CLASS_OPTIONS.keys - []).each do |var|
      CLASS_OPTIONS[var] =  copts[LONG_TO_SHORT[var]]
      set(var, CLASS_OPTIONS[var])
    end
  end

  # List the available modlets for the given code (copts[:C] or -C on the command line).
  def self.available_modlets(copts={})
    process_command_options(copts)
    puts "\nAvailable modlets for #{copts[:C]}:"
    entries = []
    begin
      entries += Dir.entries(SCRIPT_FOLDER + "/code_modules/#{copts[:C]}/my_modlets")
    rescue
    end
    begin
      entries += Dir.entries(SCRIPT_FOLDER + "/code_modules/#{copts[:C]}/default_modlets")
    rescue
    end
    entries.each do |modlet|
      puts "\t" + File.basename(modlet, '.rb') unless ['.', '..', '.svn', '.directory'].include? modlet or modlet=~ /defaults/
    end
  end

    # List the available defaults files for the given code (copts[:C] or -C on the command line).
  def self.available_defaults_files(copts={})
    process_command_options(copts)
    entries = []
    #begin
      ##entries += Dir.entries(SCRIPT_FOLDER + "/code_modules/#{copts[:C]}/my_defaults_files")
      #entries +=
    #rescue
    #end
    #begin
    #run_class = setup_run_class(copts[:C], modlet: copts[:m])
    rc = run_class(copts)
    entries = [rc.rcp.user_defaults_location, rc.rcp.code_module_folder + "/defaults_files"].map{|folder|  Dir.entries(folder).grep(/_defaults\.rb$/) rescue []}.sum
      #entries += Dir.entries(SCRIPT_FOLDER + "/code_modules/#{copts[:C]}/defaults_files")
      #entries += Dir.entries(SCRIPT_FOLDER + "/code_modules/#{copts[:C]}/defaults_files")
    #rescue
    #end
    puts "\nAvailable defaults files for #{copts[:C]}:"
    entries.each do |defaults_file|
      #puts "\t" + File.basename(defaults_file, '.rb').sub(/_defaults/, '') unless ['.', '..', '.svn', '.directory'].include? defaults_file
      puts "\t" + File.basename(defaults_file, '.rb').sub(/_defaults/, '')
    end
  end

  # Cancel the job with the given id. The user is asked interactively for 
  # confirmation and whether they would like to delete the folder for that job 
  # as well.
  def self.cancel(copts={})
    runner = fetch_runner(copts)
    runner.cancel_job(copts)
  end

  def self.continue_in_new_folder(folder, copts={})
    runner=fetch_runner(copts)
    options = {}
    if copts[:f] or copts[:j]
      options[:copy_ids] = runner.filtered_ids
    end

    runner.continue_in_new_folder(folder, options)
  end

  # Change the id of a given run to another integer
  def self.change_run_id(new_ids, copts={})
    return unless Feedback.get_boolean("Warning: changing the id of a run does "\
                                       "NOT change the restart information "\
                                       "of any run which was restarted from "\
                                       "it! Please confirm.")

    runner_all = fetch_runner()
    runs_all = runner_all.filtered_ids.map{|id| runner.combined_run_list[id]}
    runner = fetch_runner(copts)
    runs = runner.filtered_ids.map{|id| runner.combined_run_list[id]}

    new_ids = new_ids.split(',').map(&:to_i)

    if new_ids.length != runs.length
      eputs "Error: New ids and list of runs are not the same length."
      return
    end

    existing_ids = []
    runs_all.each{|r| existing_ids << r.id}

    runs.each_with_index do |r, i|
      if existing_ids.include?new_ids[i]
        eputs "Error: id #{new_ids[i]} already exists! Skipping..."
        next
      end

      r.change_id(new_ids[i])
    end
  end

  # Method which concatenates NetCDF output files 
  def self.concat(name, copts={})
    begin
      require "numru/netcdf"
    rescue LoadError
      eputs "Error: No Ruby NetCDF library (was it installed correctly?): "\
            "concatenation for netcdf files not possible."
      return
    end

    runner = fetch_runner(copts)
    runs = runner.filtered_ids.map{|id| runner.combined_run_list[id]}

    concat_string = 'ncrcat '
    runs.each do |r|
      concat_string += r.directory + '/' + r.run_name + '.out.nc '
    end

    concat_string += runner.root_folder + '/' + name

    system "#{concat_string}"
  end

  # This section defines the report report writing function in. The latex
  # header is defined in run.rb. It is a run method and can be redefined in a
  # particular CRMOD.  The function is simply called as follows:
  #
  #   interactively: wr j:<run no.> command line: coderunner write_report -j
  #   <run no>
  #
  # The requirements to use this function are:
  #
  #   1. pdflatex version 2014 or higher 2. gnuplot 3. ability to write eps
  #   graphs
  #
  # The graphs which are written out to the PDF are read in from a given CRMOD.
  # It should be defined in the main .rb file for the CRMOD, e.g. gs2.rb.  As
  # seen below, this function should be called 'latex_graphs'. To see an
  # example of what this function should look like see GS2CRMOD, but it is
  # simply an array of graphkits and latex code blocks which describe plots.
  def self.write_report(copts={})
    runner = fetch_runner(copts)
    runs = runner.filtered_ids.map{|id| runner.combined_run_list[id]}

    #Loop through the runs and write a latex file for each
    runs.each do |r|
      Dir.chdir(runner.root_folder) do
        FileUtils.makedirs("run_docs")
        FileUtils.makedirs("run_docs/id_#{r.id}")
        Dir.chdir("run_docs/id_#{r.id}") do

          File.open("summary.tex", 'w') do |file|
            file.puts r.latex_report_header
            file.puts <<-EOF.gsub(/^ {14}/, "")
              \\begin{itemize}
            EOF

            # Need to call some methods here which reads the graphs we want 
            # from gs2crmod, generates the graphs then generates the latex code 
            # to display graphs.
            latex_code = r.latex_graphs.inject("") do |tmp_latex_code, (kit, latexstring)|
              kit.gnuplot_write(kit.file_name) #write the graph
              tmp_latex_code += "\\item " + latexstring + 
                                " \n\n\\newfig{#{kit.file_name}}"
              tmp_latex_code += "\n\n"
              tmp_latex_code
            end

            file.puts <<-EOF.gsub(/^ {14}/, "")
              #{latex_code}
              \\end{itemize}
              \\end{document}
            EOF
          end #file write
          system "pdflatex summary.tex"
        end
      end #chdir
    end # run loop
  end

  def self.delete(copts={})
    runner = fetch_runner(copts)
    runner.destroy
  end

  def self.differences_between(copts = {})
    runner = fetch_runner(copts)
    runs = runner.filtered_ids.map{|id| runner.combined_run_list[id]}
    rcp_fetcher = (runs[0] || runner.run_class).rcp
    vars = rcp_fetcher.variables.dup + rcp_fetcher.run_info.dup
    vars.delete_if{|var| runs.map{|r| r.send(var)}.uniq.size == 1}
    vars.delete :id
    vars.delete :run_name
    vars.delete :output_file
    vars.delete :error_file
    vars.delete :executable
    vars.delete :comment
    vars.delete :naming_pars
    vars.delete :parameter_hash
    vars.unshift :id
    #vars.push 'File.basename(executable)'
    table = vars.map{|var| [var] + runs.map{|r| str = r.instance_eval(var.to_s).to_s; str.size>10?str[0..9]:str} }
    #vars[-1] = 'exec'
    col_widths = table.map{|row| row.map{|v| v.to_s.size}}.inject{|o,n| o.zip(n).map{|a| a.max}}
    eputs
    table.each{|row| i=0; eputs row.map{|v| str = sprintf(" %#{col_widths[i]}s ", v.to_s); i+=1; str}.join('|'); eputs '-' * (col_widths.sum + col_widths.size*3 - 1) }
    #p table, col_widths
  end

  def self.dumb_film(copts = {})
#     process_copts(copts)
    #old_term = GraphKit::GNUPLOT_DEFAULT_TERM
    size = Terminal.terminal_size
    size[0] -= 2
    term = "dumb #{size.reverse.join(' ')}"
    string = "\n" * size[0]

    runner = fetch_runner(copts)
    string_to_eval = copts[:w]
    frame_array = copts[:F][:frame_array] || copts[:F][:fa]
    index_name = copts[:F][:index_name] || copts[:F][:in]
    #options = (options and options =~ /\S/) ? eval(options): {}
    puts string
    for index in frame_array[0]..frame_array[1]
      string.true_lines.times{print "\033[A"}
      kit = runner.graphkit_from_lists(copts[:G], copts[:g], index_name => index)
      kit.gp.term =  term
      kit.gnuplot(eval: string_to_eval)
      sleep(copts[:F][:fr] ? 1.0/copts[:F][:fr] :  0.1)
    end
  end 

  def self.netcdf_plot(netcdf_file, vars, indices, copts={})
    process_command_options(copts)
    begin
      require "numru/netcdf"
    rescue LoadError
        eputs "Error: No Ruby NetCDF library (was it installed correctly?): data analysis for netcdf files not possible."
        return
    end
    start_indices = indices.split(',').map{|idx|  idx = idx.split(':')[0] if idx =~ /:/ ; eval(idx) || 0}
    end_indices = indices.split(',').map{|idx| idx = idx.split(':')[1] if idx =~ /:/ ; eval(idx) || -1}

    ep 'start_indices', start_indices, 'end_indices', end_indices
    file = NumRu::NetCDF.open(netcdf_file)
    to_plot = vars.split(',').map do |var|
      ep 'var', var
      [file.var(var).get('start'=> start_indices, 'end'=> end_indices).to_a.flatten]
    end
    ep 'to_plot', to_plot
    kit = GraphKit.quick_create(*to_plot)
    ep 'copts', copts
    kit.instance_eval(copts[:w]) if copts[:w]
    kit.gnuplot
    STDIN.gets
    kit.close
  end

  def self.print_queue_status(copts={})
    begin
      eputs queue_status
    rescue => _err
      eputs "General queue status doesn't work on this system; showing queue status for this folder"
      #ep err
      runner = fetch_runner(copts)
      eputs runner.queue_status
    end
  end

  # Used by the help method defined in interactive_methods.rb
  def self.reference(class_or_method, copts={})
    begin
      eputs "Looking up #{class_or_method}"
      RDoc::RI::Driver.run [class_or_method.to_s] 
    rescue SystemExit => err
      eputs "Unknown class or method or no help available: #{err}"
    end
  end

  def self.directory(id, copts={})
    runner = fetch_runner(copts)
    puts runner.run_list[id.to_i].directory
  end

  def self.film(copts={})
    runner = fetch_runner(copts)
    copts[:F][:graphkit_modify] = copts[:w]
    runner.make_film_from_lists(copts[:G], copts[:g], copts[:F])
  end

  # Deprecated
  def self.generate_documentation(username = nil, copts = {})
    ep 'username', username||=ENV['USER']

    ####### Here we use the command line documentation to generate a fake ruby file that rdoc will understand.
    File.open("class_methods_rdoc.rb", 'w') do |file|
      file.puts <<EOF
  class CodeRunner


#{COMMANDS_WITH_HELP.inject("") do |str, (long, _short, _nargs, comhelp, argnames, options)|
  (puts "Please run this command in the coderunner trunk directory"; exit) unless Dir.pwd =~ /coderunner\/trunk$/
    str << <<EOF2
  # #{comhelp.gsub(/\n/, "\n  # ")}
  #
  # Possible options:
  #
#{options.inject("") do |strr, opt|
    _longop, _shortop, _req, ophelp = COMMAND_LINE_FLAGS_WITH_HELP.find{|arr| arr[1] == "-" + opt.to_s}
    strr << "  # :#{opt} --- #{ophelp.gsub(/\n/, "\n  # ")}\n  #\n"
  end}

  def self.#{long}(#{(argnames+[""]).join(",")}command_options={})
  end

EOF2
  end
  }
  end
EOF
    end
#     exit

    system "rm -rf doc/"
    system "rm -rf ri/"
    raise 'Please set RDOC_COMMAND' unless ENV['RDOC_COMMAND']
    system "#{ENV['RDOC_COMMAND']} --format=html -t 'CodeRunner Documentation' -m INDEX.rb  INDEX.rb code_runner_version.rb gnuplot.rb graphkit_gnuplot.rb graphkit.rb gsl_tools.rb  run_backwards_compatibility.rb feedback.rb run.rb fortran_namelist.rb graphs_and_films.rb  class_methods_rdoc.rb instance_methods.rb"
    system "#{ENV['RDOC_COMMAND']} -r --op ri INDEX.rb code_runner_version.rb gnuplot.rb graphkit_gnuplot.rb graphkit.rb gsl_tools.rb  run_backwards_compatibility.rb feedback.rb run.rb fortran_namelist.rb graphs_and_films.rb  class_methods_rdoc.rb instance_methods.rb"

    exit if username == ""

    string = "rsync -av --delete doc/  #{username},coderunner@web.sourceforge.net:htdocs/api_documentation/"

    puts string
    exec string

  end

  def self.generate_cubecalc(copts={})
    #return
    File.open('cubecalc.cc', 'w') do |file|
    file.puts <<EOF
#include <stdio.h>
#include <iostream>
#include <cstdlib>
#include <fstream>
#include <cstring>
#include <ctime>
using namespace std;

int main(int argc, char* argv[]){
  string line;
  cout << "Starting..." << endl;

  int calculate_sides = atoi(argv[1]); //Should the program calculate the area of the sides of the cube?
  cout << calculate_sides << endl;

  char* input_file_name = argv[2]; //Get the input file name from the command line
  cout << input_file_name << endl;

  if (argc > 3){ //It has been told to sleep for a time
    bool cont = true;
    time_t start_t;
    time(&start_t);
    while (cont){
      time_t new_t;
      time(&new_t);
      cont = (new_t < (start_t + atoi(argv[3]) * 1.0));
    }
  }

  ifstream edges_file(input_file_name); //Read the edges from the input file
  float* edges = new float[3];
  int j = 0;
  while (edges_file >> edges[j++]){
    cout << edges[j-1] << endl;
  }


  FILE* output = fopen("results.txt", "w"); //Write the volume to the output file
  fprintf(output, "Volume was %f", edges[0] * edges[1] * edges[2]);
  fclose(output);

  if (calculate_sides == 1){ //If it has been told to calculate the sides
    cout << "calculating sides" << endl;
    FILE* sides = fopen("sides.txt", "w");
    for(int i=0; i<3; i++){
      cout << "Side " << i << ": " << edges[(i%3)] * edges[((i+1)%3)] << endl;
      fprintf(sides, "The area of side %d is %f\\n", i, edges[i%3] * edges[(i+1)%3]);
    }
    fclose(sides);
  }
}



EOF

    end
  end

  def self.launcher_directory
    ENV['HOME'] + "/.coderunner/to_launch/#{global_options(:launcher)}"
  end
  
  def self.start_launcher(refresh, max_queue, copts={})
    #eputs "Starting launcher!"
    raise "Raise refresh is #{refresh}: it must be >= 0.1" if refresh.to_f < 0.1
    raise "Raise max_queue is #{max_queue}: it must be >= 5" if max_queue.to_i < 5
    #raise "Launcher already running" if %x[ps -e -o cmd].split("\n").grep(/coderunner\s+launch/).size > 0
    require 'thread'
    tl = launcher_directory #SCRIPT_FOLDER + '/to_launch'
    #exit unless Feedback.get_boolean( "Launch directory #{tl} already exists: it is suggested that you change the prefix by changing the environment variable CODE_RUNNER_LAUNCHER. Do you wish to continue (don't select yes unless you know what you are doing)?") if FileTest.exist? tl
    raise "Launch directory #{tl} already exists: it is suggested that you change the prefix by changing the environment variable CODE_RUNNER_LAUNCHER. Do you wish to continue (don't select yes unless you know what you are doing)?" if FileTest.exist? tl
#     FileUtils.rm_r tl if FileTest.exist? tl
    eputs "Starting launcher\n"
    at_exit{FileUtils.rm_r tl}
    FileUtils.makedirs tl

    unless global_options(:launcher) =~ /serial/
      mutex = Mutex.new
      processes= []
      command_list = {}

      Thread.new do
        loop do
          `cp #{tl}/queue_status.txt #{tl}/queue_status2.txt`
          #`ps > #{tl}/queue_status.txt`
          mutex.synchronize do 
            File.open("#{tl}/queue_status.txt", 'w') do |f| 
              # This ensures that the right pids will be listed,
              # regardless of the way that ps behaves
              f.puts processes.map{|pid| "#{pid} #{command_list[pid].gsub(/\n|\r/, '')}"}
            end
          end
          sleep 1
        end
      end


      Thread.new do
        loop do
          Dir.entries(tl).each do |file|
            next unless file =~ (/(^.*)\.stop/)
            pid = $1
            mutex.synchronize{Process.kill(pid); processes.delete pid}
          end
          sleep refresh.to_i
        end
      end

      #Dir.chdir(tl) do
      ppid = $$
      loop do
        sleep refresh.to_i while processes.size >= max_queue.to_i
#         processes = []
        Dir.entries(tl).grep(/(^.*)\.start/).each do |file|
          file =~ (/(^.*)\.start/)
          id = $1
          command = ""
          command = File.read tl + '/' + file while command == ""
          pid = fork do
            processes.each do |wpid|
              # Make sure all previously submitted jobs have finished.
              sleep refresh.to_i while %x[ps -e -o pid,ppid].split("\n").grep(Regexp.new("^\\s*#{wpid}\\s+#{ppid}")).size > 0
            end
            #p ["command", command]
            exec(command + "\n wait")
          end
          `cp #{tl}/queue_status.txt #{tl}/queue_status2.txt; ps > #{tl}/queue_status.txt`
          mutex.synchronize do
            processes.push pid
            command_list[pid] = command
          end

          File.open(tl + '/' + id + '.pid', 'w'){|fle| fle.puts pid}
          FileUtils.rm(tl + '/' + file)

          Thread.new{Process.wait pid; mutex.synchronize{processes.delete pid; command_list.delete(pid)}}
        end
#         processes.each{|pid| Process.wait pid}
        sleep refresh.to_i
      end
    #end
      #
    else
      loop do
        Dir.entries(tl).grep(/(^.*)\.start/).each do |file|
          file =~ (/(^.*)\.start/)
          id = $1
          command = ""
          command = File.read tl + '/' + file while command == ""
          pid = 12345
          File.open(tl + '/' + id + '.pid', 'w'){|fle| fle.puts pid}
          File.open("#{tl}/queue_status.txt", "w"){|fle| fle.puts pid}
          `cp #{tl}/queue_status.txt #{tl}/queue_status2.txt`
          FileUtils.rm(tl + '/' + file)
          system "#{command} \n\n wait \n\n"
          File.open("#{tl}/queue_status.txt", "w"){|fle| fle.puts}
          `cp #{tl}/queue_status.txt #{tl}/queue_status2.txt`
        end
        sleep refresh.to_i
      end
    end

  end

  def self.code_runner_execute(ruby_fragment, copts={})
    #eval(ruby_fragment, GLOBAL_BINDING)
    eval(ruby_fragment)
  end

  def self.execute(ruby_fragment, copts={})
    eval(ruby_fragment, GLOBAL_BINDING)
    #eval(ruby_fragment)
  end
  
  def self.load_file(files, copts={})
    process_command_options(copts)
#     begin
      files.split(/\s*,\s*/).each do |file|
#         p file
        raise ArgumentError.new("#{file} is not a file.") unless File.file? file
        load file
      end
#     rescue
#       eval(files)
#     end

  end

  def self.parameter_scan(parameter_scan_array_file, copts={})
    parameter_scan_array = eval(File.read(parameter_scan_array_file))
#       process_copts(copts)
    runner = fetch_runner(copts)
    skip = true unless copts[:k] == false
    #_folder = Dir.pwd
    Log.logf("self.parameter_scan")
#     @@runners = {}
    @@mutex = Mutex.new
#     @runner = new(folder, code: copts[:C], modlet: copts[:m], version: copts[:v], executable: copts[:X])
    @@psppipe = PPipe.new(parameter_scan_array.size + 2,  true, controller_refresh: 0.5, redirect: false)
    parameter_scan_array.each do |parameter_scan|
        @@psppipe.fork do
          runner.parameter_scan(parameter_scan, copts[:p][0], skip: skip, nprocs: copts[:n])
        end
    end
    @@psppipe.finish
    @@psppipe = nil
  end

  def self.plot_graph(copts = {})
#     process_copts(copts)
    runner = fetch_runner(copts)
    string_to_eval = copts[:w]
    #options = (options and options =~ /\S/) ? eval(options): {}
    eputs 'Starting Graph'
    kit = runner.graphkit_from_lists(copts[:G], copts[:g])
    kit.gnuplot(eval: string_to_eval)
    #gets
    #kit.close
  end

  def self.readout(copts={})
    runner = fetch_runner(copts)
    puts runner.readout
  end
  
  def self.recheck(id, copts={})
    runner = fetch_runner(copts)
    runner.run_list[copts[:R]].recheck
    runner.respond_to_requests
  end

  def self.run_class(copts={})
    process_command_options(copts)
    copts[:no_update] = true
    unless copts[:C]
      if FileTest.exist? file=Dir.pwd + '/.code_runner_script_defaults.rb'
        copts[:C] = eval(File.read(file))[:code]
        copts[:m] = eval(File.read(file))[:modlet]
      elsif self.runner
        copts[:C] = self.runner.code
        copts[:m] = self.runner.modlet
      end
    end
    #ep ['code', 'modlet is', copts[:C], copts[:m]]

    return setup_run_class(copts[:C], modlet: copts[:m])
  end

  def self.code_command(string, copts = {})
    run_class(copts).class_eval(string)

#      runner = fetch_runner(copts)
#      runner.run_class.class_eval(string)
  end
  
  def self.run_command(string, copts={})
#       process_copts(copts)
    runner = fetch_runner(copts)

    eputs "Calling run_commmand..."
#     puts "Warning: Use large cache is on (-U or -u) -- no results will be saved" if runner.use_large_cache
    ppipe = PPipe.new(runner.filtered_ids.size + 1, false) if copts[:M]
    no_save = (runner.class == RemoteCodeRunner or copts[:y] =~ /no-save/)
#   runner.generate_combined_ids
#   ep runner.filtered_ids
    runner.filtered_ids.each do |id|
      run = runner.combined_run_list[id]

      if no_save or run.is_component
        if copts[:M]
          fork{run.instance_eval(string)}
        else
          run.instance_eval(string)
        end
      else
        if copts[:M]
          _pn = ppipe.fork do
            Dir.chdir(run.directory) do
              run.instance_eval(string);
              run.save
              run.write_results
            end
            ppipe.i_send(id, Marshal.dump(run), tp: 0)
          end
        else
          Dir.chdir(run.directory){run.instance_eval(string); run.save; run.write_results}
        end

      end
    end
    unless no_save
      (runner.filtered_ids.each{|id| runner.run_list[id] = Marshal.load(ppipe.w_recv(id).contents)};ppipe.finish) if copts[:M]
      runner.save_large_cache
    end

#     Process.waitall
    runner.respond_to_requests
  end

  def self.runner_eval(string, copts = {})
#      process_copts(copts)
     runner = fetch_runner(copts)

     #ep ['server string is', string]

     return_val = runner.instance_eval(string)

     if copts[:Z]
       Kernel.puts(server_dump(return_val))
     else
       return return_val
     end

  end
  
  def self.scan(scan_string, copts={})
#       process_copts(copts)
    runner = fetch_runner(copts)
      runner.simple_scan(scan_string, nprocs: copts[:n], version: copts[:v], skip: copts[:k], parameters: copts[:p][0])
  end

  def self.submit(copts = {})
#     process_copts(copts)
    runner = get_submit_runner(copts)
#     raise "something is already submitting" if FileTest.exist? "submitting"
    runs = []
    raise "Parameters must be an array of inspected hashes" unless copts[:p].kind_of? Array
    #raise "Can't submit using a merged runner" if runner.kind_of? CodeRunner::Merged
    Dir.chdir(runner.root_folder) do

      copts[:p].push nil if copts[:p] == []
  #         ep copts[:p]; exit
      copts[:p].each do |pars|
        run = runner.run_class.new(runner)
  #       p pars
        run.update_submission_parameters(pars)
        runs.push run
      end
#       exit
    end
    runner.submit(runs, nprocs: copts[:n], version: copts[:v], skip: copts[:k], job_chain: copts[:J], no_update_before_submit: copts[:no_update_before_submit])
    #exit(0)
  end

  # Fetch a runner appropriate for submitting simulations. In 
  # all usual cases this is just the default runner for the command
  # but where several folders have been specified and we are dealing
  # with a merged runner, a single runner is chosen from the merged
  # runners using submit_runner_index
  def self.get_submit_runner(copts)
    runner = fetch_runner(copts)
    unless runner.kind_of? CodeRunner::Merged
      return runner
    else
      unless copts[:submit_runner_index]
        raise "You can't submit runs using a merged runner. Please specify the option --submit-runner-index (or submit_runner_index in interactive mode)"
      else
        return runner.runners[copts[:submit_runner_index]]
      end
    end
  end

  def self.resubmit(copts = {})
    runner = get_submit_runner(copts)
    runs = []
    raise "Parameters must be an array of inspected hashes" unless copts[:p].kind_of? Array
    Dir.chdir(runner.root_folder) do
      runs = runner.filtered_ids.map do |id|
        eputs id
        run = runner.run_list[id].dup
        run.output_file = nil
        run.error_file = nil

        run.resubmit_id = run.id
        if copts[:smart_resubmit_name]
          eputs "Smart name"
          run.set(:naming_pars,  [:resubmit_id])
        end
        run.update_submission_parameters(copts[:p][0], false)
        run.run_name = nil unless copts[:rerun]
        run
      end
    end

    runner.submit(runs, nprocs: copts[:n], version: copts[:v], skip: copts[:k], job_chain: copts[:J], no_update_before_submit: copts[:no_update_before_submit], replace_existing: copts[:replace_existing], smart_resubmit_name: copts[:smart_resubmit_name], rerun: copts[:rerun])
  end

  # This method allows the straightforward submission of a single command using 
  # the batch queue on any system.
  def self.submit_command(jid, comm, copts={})
    process_command_options(copts)
    submitter = Object.new
    submitter.instance_variable_set(:@command, comm)
    submitter.instance_variable_set(:@jid, jid)
    submitter.instance_variable_set(:@nprocs, copts[:n])
    submitter.instance_variable_set(:@wall_mins, copts[:W])
    submitter.instance_variable_set(:@project, copts[:P])
    class << submitter
      include CodeRunner::SYSTEM_MODULE
      def executable_name
        'custom'
      end
      def job_identifier
        @jid
      end
      def run_command
        @command
      end
    end
    submitter.execute
  end

  def self.readout(copts={})
    runner = fetch_runner(copts)
    runner.readout
  end

  def self.show_values_of(expression, copts={})
    runner = fetch_runner(copts)
    p runner.filtered_ids.map{|id| runner.combined_run_list[id].instance_eval(expression)}.uniq.sort
  end
  
  def self.status_with_comments(copts={})
    copts[:with_comments] = true
    status(copts)
  end
  
  def self.status(copts={})
#     process_copts(copts)
    runner = fetch_runner(copts)
    runner.print_out(0, with_comments: copts[:with_comments]) unless copts[:interactive_start] or copts[:Z] or copts[:no_print_out]
  end
  
  def self.status_loop(copts={})
#     process_copts(copts)
    runner = fetch_runner(copts)
    runner.print_out(0, with_comments: copts[:with_comments]) unless copts[:interactive_start] or copts[:Z] or copts[:no_print_out]
    break_out = false
    loop do
      old_trap = trap(2){eputs " Terminating loop, please wait..."; break_out = true}
      runner.use_large_cache = true
      runner.update(false)
      (trap(2, old_trap); break) if break_out
      runner.recheck_filtered_runs(false)
      runner.print_out(nil, with_comments: copts[:with_comments])
      trap(2, old_trap)
      break if break_out
      break if not runner.run_list.values.find do |r|
        not [:Complete, :Failed].include? r.status
      end
      #ep "sleep"
      sleep 3
      #ep "end sleep"
    end
  end

  def self.status_loop_running(copts={})
    copts[:f] = "@running"
    runner = fetch_runner(copts)
    ids = runner.filtered_ids
    copts[:f] = "#{ids.inspect}.include? id"
    copts[:j] = nil
    status_loop(copts)
  end
  
  def self.status_loop(copts={})
#     process_copts(copts)
    runner = fetch_runner(copts)
    runner.print_out(0, with_comments: copts[:with_comments]) unless copts[:interactive_start] or copts[:Z] or copts[:no_print_out]
    break_out = false
    loop do
      old_trap = trap(2){eputs " Terminating loop, please wait..."; break_out = true}
      runner.use_large_cache = true
      runner.update(false)
      (trap(2, old_trap); break) if break_out
      runner.recheck_filtered_runs(false)
      runner.print_out(nil, with_comments: copts[:with_comments])
      trap(2, old_trap)
      break if break_out
      break if not runner.run_list.values.find do |r|
        not [:Complete, :Failed].include? r.status
      end
      #ep "sleep"
      sleep 3
      #ep "end sleep"
    end
  end

  def self.write_graph(name, copts={})
#     process_copts(copts)
    runner = fetch_runner(copts)
    eputs 'Starting Graph'
    kit = runner.graphkit_from_lists(copts[:G], copts[:g])
    #options = copts[:w]
    #options = (options and options =~ /\S/) ? eval(options): {}
    name = nil unless name =~ /\S/
    max = 0
    name.sub!(/^\~/, ENV['HOME']) if name
    if name and name =~ /%d\./
      regex = Regexp.new(Regexp.escape(File.basename(name)).sub(/%d/, '(?<number>\d+)'))
      Dir.entries(File.dirname(name)).join("\n").scan(regex) do
        max = [max, $~[:number].to_i].max
      end
      name = name.sub(/%d/, (max + 1).to_s)
    end
    raise "kit doesn't have a file_name and no filename specified; can't write graph" unless name or (kit.file_name.class == String and kit.file_name =~ /\S/)
    Dir.chdir(COMMAND_FOLDER){kit.gnuplot_write((name or kit.file_name), {eval: copts[:w]})}
  end

  def self.read_default_command_options(copts)
    DEFAULT_COMMAND_OPTIONS.each do |key, value|
      copts[key] ||= value
    end
  end
  
  def self.process_command_options(copts)
    if copts[:true]
      copts[:true].to_s.split(//).each do |letter|
        copts[letter.to_sym] = true
      end
    end
    if copts[:false]
      copts[:false].to_s.split(//).each do |letter|
        copts[letter.to_sym] = false
      end
    end

    read_default_command_options(copts)
    copts.each do |key, value|
      copts[LONG_TO_SHORT[key]] = value if LONG_TO_SHORT[key]
    end


    if copts[:j] # j can be a number '65' or list of numbers '65,43,382'
      copts[:f]= "#{eval("[#{copts[:j]}]").inspect}.include? id"
    end
    if copts[:X] and FileTest.exist? copts[:X]
      copts[:X] = File.expand_path(copts[:X])
    end
    if copts[:z]
      Log.log_file = Dir.pwd + '/.cr_logfile.txt'
      Log.clean_up
    else
      Log.log_file = nil
    end
    copts[:F] = (copts[:F].class == Hash ? copts[:F] : (copts[:F].class == String and copts[:F] =~ /\A\{.*\}\Z/) ? eval(copts[:F]) : {})
    copts[:G]= [copts[:G]] if copts[:G].kind_of? String
    copts[:g]= [copts[:g]] if copts[:g].kind_of? String
#     if copts[:p] and copts[:p].class == String # should be a hash or an inspected hash
#       copts[:p] = eval(copts[:p])
#     end
    copts[:p] = [copts[:p]].compact unless copts[:p].class == Array
    #for i in 0...copts[:p].size
    case copts[:h]
    when :c, :component
      copts[:h] = :component
    when :r, :real
      copts[:h] = :real
    else
      copts[:h] = :real
    end

#     ep Log.log_file
    #copts[:code_copts].each{|k,v| CODE_OPTIONS[k] = v} if copts[:code_copts]
    copts.keys.map{|k| k.to_s}.grep(/_options$/).map{|k| k.to_sym}.each do |k|
      CODE_OPTIONS[k.to_s.sub('_options','').to_sym] = copts[k]
    end


  end

  # Analyse copts[:Y], the choice of the root folder for the runner, and make 
  # appropriate modifications to the command options for running remotely, etc.
  def self.process_root_folder(copts)
    copts[:Y] ||= DEFAULT_COMMAND_OPTIONS[:Y] if DEFAULT_COMMAND_OPTIONS[:Y]
    if copts[:Y] and copts[:Y].kind_of? Array
      eputs "Warning: ignoring additional folders... selecting folder: #{copts[:Y]=copts[:Y][0]}"
    end
    if copts[:Y] and copts[:Y] =~ /:/
      set_class_defaults(copts)
      copts[:running_remotely] = true
    else
      copts[:Y] = copts[:Y].gsub(/~/, ENV['HOME']) if copts[:Y]
      Dir.chdir((copts[:Y] or Dir.pwd)) do
        set_runner_defaults(copts)
#         ep DEFAULT_RUNNER_OPTIONS
      end
    end
  end

  CODE_OPTIONS={}

  # Retrieve the runner with the folder (and possibly server) given in 
  # copts[:Y]. If no runner has been loaded for that folder, load one.
  def self.fetch_runner(copts={})
#     ep copts
    #read_default_command_options(copts)
    process_command_options(copts)
    # If copts(:Y) is an array of locations, return a merged runner of those locations
    #copts[:Y] ||= DEFAULT_COMMAND_OPTIONS[:Y] if DEFAULT_COMMAND_OPTIONS[:Y]
    if copts[:Y].kind_of? Array
      runners = copts[:Y].map do |location|
        new_copts = copts.dup.absorb(Y: location)
        fetch_runner(new_copts)
      end
      return Merged.new(*runners)
    end
    process_root_folder(copts)
    #ep copts
    @runners ||= {}
    runner = nil
    if copts[:Y] and copts[:Y] =~ /:/
      copts_r = copts.dup
      host, folder = copts[:Y].split(':')
      copts_r[:Y] = nil
      copts[:Y] = nil
      unless @runners[[host, folder]]
        copts[:cache] ||= :auto
        runner = @runners[[host, folder]] = RemoteCodeRunner.new(host, folder, copts)
        #(eputs 'Updating remote...'; runner.update) unless (copts[:g] and (copts[:g].kind_of? String or copts[:g].size > 0)) or copts[:no_update] or copts[:cache]
      else
        runner = @runners[[host, folder]]
      end
      runner.process_copts(copts)
    else

      copts[:Y] ||= Dir.pwd
        Dir.chdir((copts[:Y] or Dir.pwd)) do
        unless @runners[copts[:Y]]
          runner = @runners[copts[:Y]] = CodeRunner.new(Dir.pwd, code: copts[:C], modlet: copts[:m], version: copts[:v], executable: copts[:X], defaults_file: copts[:D])
          runner.update unless copts[:no_update]
        else
          runner = @runners[copts[:Y]]
        end
        # This call ensures that even if we are using an existing
        # runner, it still uses the new copts  
        runner.read_defaults
        #p 'read defaults', runner.recalc_all

      end #Dir.chdir
    end
#     ep copts
    return runner
#     @r.read_defaults
  end

  def self.update_runners
    @runners ||= {}
    @runners.each{|runner| runner.update}
  end

  def self.runner
    @runners ||={}
    @runners.values[0]
  end

  def self.manual(copts={})
    help = <<EOF


-------------CodeRunner Manual---------------

  Written by Edmund Highcock (2009)

NAME

  coderunner


SYNOPSIS

  coderunner <command> [arguments] [options]


DESCRIPTION

  CodeRunner is a framework for the running and analysis of large simulations. It is a Ruby package and can be used to write Ruby scripts. However it also has a powerful command line interface. The aim is to be able to submit simulations, analyse data and plot graphs all using simple commands. This manual is a quick reference. For a more tutorial style introduction to CodeRunner go to
       http://coderunner.sourceforge.net

  This help page documents the commandline interface. For API documentation see
       http://coderunner.sourceforge.net/api_documentation

  As is standard, <> indicates a parameter to be supplied, and [] indicates an option, unless otherwise stated.

EXAMPLES

   $ coderunner sub -p '{height: 34.2, width: 221}' -n 24x4 -W 300

   $ coderunner can 34 -U

   $ coderunner plot -G 'height:width;{};depth==2.4 and status == :Completed;height'

   $ coderunner st -ul

   $ coderunner rc 'p status' -U

COMMANDS

   Either the long or the short form of the command may be used, except in interactive mode, where only short form can be used.

    Long(Short)  <Arguments>  (Meaningful Options)
    ---------------------------------------------

#{(COMMANDS_WITH_HELP.sort_by{|arr| arr[0]}.map do |arr|
     sprintf(" %s %s(%s) \n\t%s", "#{arr[0]}(#{arr[1]})",    arr[4].map{|arg| "<#{arg}>"}.join(' ').sub(/(.)$/, '\1 '), arr[5].map{|op| op.to_s}.join(','), arr[3], )
    end).join("\n\n")}

OPTIONS

#{((COMMAND_LINE_FLAGS_WITH_HELP + LONG_COMMAND_LINE_OPTIONS).map do |arr|
   sprintf("%-15s %-2s\n\t%s", arr[0], arr[1], arr[3])
  end).join("\n\n")
    }

EOF
     #help.gsub(/(.{63,73} |.{73})/){"#$1\n\t"}.paginate
     help.paginate
  end

end
