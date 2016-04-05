#############################################
## Default configuration for interactive mode
############################################


$has_put_startup_message_for_code_runner = true #please leave!
$code_runner_interactive_mode = true #please leave!
require 'yaml'

def reset
  Dispatcher.reset_application!
end

IRB.conf[:AUTO_INDENT] = true
IRB.conf[:USE_READLINE] = true
IRB.conf[:LOAD_MODULES] = []  unless IRB.conf.key?(:LOAD_MODULES)

unless IRB.conf[:LOAD_MODULES].include?('irb/completion')
  IRB.conf[:LOAD_MODULES] << 'irb/completion'
end      


require 'irb/completion'
require 'irb/ext/save-history'
require 'socket'
unless CodeRunner.global_options(:simple_prompt) 
  #prompt_start = "\001#{Terminal::LIGHT_GREEN}\002CodeRunner\001#{Terminal::RESET}\002 v#{CODE_RUNNER_VERSION} - \001#{Terminal::CYAN}\002#{ENV['USER']}@#{Socket::gethostname}:#{File.basename(Dir.pwd)}\001#{Terminal::RESET}\002 timemarker\n"
  prompt_start = "\001#{Terminal::LIGHT_GREEN}\002CodeRunner\001#{Terminal::RESET}\002 v#{CodeRunner::CODE_RUNNER_VERSION} - \001#{Terminal::CYAN}\002#{Socket::gethostname}:#{File.basename(Dir.pwd)}\001#{Terminal::RESET}\002 timemarker %02n,%i \n"
else
  prompt_start = "CodeRunner #{File.basename(Dir.pwd)}"
end
#IRB.conf[:PROMPT][:CODE_RUNNER] = {:PROMPT_I=>"#{prompt_start}>> %02n,%i >> ", :PROMPT_N=>"#{prompt_start}>> %02n:%i > ", :PROMPT_S=>"#{prompt_start}>> %02n:%i (%l)> ", :PROMPT_C=>"#{prompt_start}>> %02n:%i >>  ", :RETURN=>""}
IRB.conf[:PROMPT][:CODE_RUNNER] = {:PROMPT_I=>"#{prompt_start}>> ", :PROMPT_N=>"#{prompt_start}> ", :PROMPT_S=>"#{prompt_start}(%l)> ", :PROMPT_C=>"#{prompt_start}>>  ", :RETURN=>""}
#   IRB.conf[:PROMPT][:CODE_RUNNER] = {:PROMPT_I=>"#{prompt_start} %02n,%i>> ", :PROMPT_N=>"#{prompt_start} %02n:%i> ", :PROMPT_S=>"#{prompt_start} %02n:%i (%l)> ", :PROMPT_C=>"#{prompt_start} %02n:%i>>  ", :RETURN=>""}


IRB.conf[:PROMPT_MODE] = :CODE_RUNNER
IRB.conf[:SAVE_HISTORY] = 400
IRB.conf[:HISTORY_FILE] = "#{Dir.pwd}/.code-runner-irb-save-history"
IRB.conf[:INSPECT_MODE] = false

if FileTest.exist? conf = CodeRunner::CONFIG_FOLDER + '/interactive_config.rb'
  load conf
end

module Kernel

	alias_method(:shell_do, "`".to_sym)
	def `(cmd)
		c =caller
		if c[0] =~ /irb_binding/
			system(cmd)
		else
			shell_do(cmd)
		end
	end
end
