class CodeRunner
  require SCRIPT_FOLDER + '/system_modules/launcher.rb'
  module GenericLinux
    include Launcher

    # @@ruby_command = "ruby1.9"

    def queue_status
      if use_launcher
        queue_status_launcher
      else
        if methods.include?(:rcp) and rcp.uses_mpi? and rcp.uses_mpi
          return %x[ps -e -U #{Process.uid} | grep mpi] + %x[ps -e -U #{Process.uid} | grep -G '\\bsh\\b'] + %x[ps -e -U #{Process.uid} -o pid,user,cmd | grep coderunner].grep(/launch/)
        else
          return %x[ps -e -U #{Process.uid} | grep '#{executable_name}'] + %x[ps -e -U #{Process.uid} | grep -G '\\bsh\\b']
        end
      end
    end

    def run_command
      crenv = @code_run_environment ? @code_run_environment + ";" : nil
        if rcp.uses_mpi
        raise "Number of processors (nprocs) not specified" unless @nprocs
            return %[#{crenv} time mpirun -np #{@nprocs} #{executable_location}/#{executable_name} #{parameter_string} > #{output_file} 2> #{error_file}]
        else
            return %[#{crenv} #{executable_location}/#{executable_name} #{parameter_string} > #{output_file} 2> #{error_file}]
        end
    end		

    def execute
        log 'execute_submission'
    # 	ppipe = PPipe.new(2, false)
    #   trap(0){}
    # 	ppipe.fork do
    #     trap(0, 'IGNORE')
    # 		trap(2, 'IGNORE')
    # 		pid =  system(run_command + " & ") #  fork{exec run_command}
    # 		ppipe.w_send(:pid, pid, tp: 0)
    # 		Thread.new{Process.wait(pid)} # Need to pick up the dead process when it finishes
    # 	end
    # 	pid = ppipe.w_recv(:pid)
    # 	ppipe.die
    #   eputs "HERE"
      
    #   trap(0){}
    #   trap(2, 'IGNORE')
    # 	pid = spawn("trap '' 2 && trap '' 0 && " + run_command + " & ")
      if prefix = ENV['CODE_RUNNER_LAUNCHER']
        launch_id = "#{Time.now.to_i}#{$$}"
        fname = CodeRunner.launcher_directory + "/#{launch_id}"
        File.open(fname + '.start', 'w'){|file| file.puts "cd '#{Dir.pwd}';#{run_command}"}
        sleep 1 until FileTest.exist? fname + '.pid'
        pid = File.read(fname + '.pid').to_i
        FileUtils.rm fname + '.pid'
      else
        #pid = Kernel.spawn(run_command + " ")
        system run_command
            pid = -1
      end
      
    #   require 'rbconfig'
    #   pid = spawn %[#{Config::CONFIG['bindir']}/#{Config::CONFIG['ruby_install_name']} -e 'puts fork{exec("#{run_command}")}' &]
      
    #   eputs "THERE"
    # 	Thread.new{Process.wait(pid)}
    #  	sleep 0.2
        return pid
    end

    def cancel_job
      children = `ps --ppid #@job_no`.scan(/^\s*(\d+)/).map{|match| match[0].to_i}
      system "kill #{@job_no}"
      children.each do |pid|
        system "kill #{pid}"
      end
    end

    def error_file
            return "#{executable_name}.#{job_identifier}.e"
    end

    def output_file
            return "#{executable_name}.#{job_identifier}.o"
    end
  end
end
