class CodeRunner

  # A module containing methods for submitting runs using the CodeRunner
  # launcher. Typically this would be used on a home Linux system or in
  # an interactive session on a supercomputer.
  module Launcher
    def launcher_prefix
		  CodeRunner.global_options(:launcher)
    end
    def use_launcher
      launcher_prefix
    end
    def queue_status_launcher
			#%x[cat #{CodeRunner.launcher_directory}/queue_status.txt | grep sh]  +
			#%x[cat #{CodeRunner.launcher_directory}/queue_status2.txt | grep sh] 
			%x[cat #{CodeRunner.launcher_directory}/queue_status.txt ]  +
			%x[cat #{CodeRunner.launcher_directory}/queue_status2.txt ] 
    end 
    def execute_launcher
			launch_id = "#{Time.now.to_i}#{$$}"
			fname = "#{CodeRunner.launcher_directory}/#{launch_id}"
			File.open(fname + '.start', 'w'){|file| file.print "cd #{Dir.pwd};", run_command, "\n"}
			sleep 2 until FileTest.exist? fname + '.pid'
			pid = File.read(fname + '.pid').to_i
			FileUtils.rm fname + '.pid'
			return pid
    end
    def cancel_job_launcher
			fname = CodeRunner.launcher_directory + "/#{$$}.stop"
			File.open(fname, 'w'){|file| file.puts "\n"}
    end
    def error_file_launcher
      return "#{executable_name}.#{job_identifier}.e"
    end
    def output_file_launcher
      return "#{executable_name}.#{job_identifier}.o"
    end
  end
end
