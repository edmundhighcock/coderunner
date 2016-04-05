#In this file we set up the global coderunner configuration
#

require 'rubygems'
require "rubyhacks"
require 'fileutils'
require 'coderunner/version'

class CodeRunner

  GLOBAL_OPTIONS = {
    system: 'generic_linux', # See coderunner/system_modules for more options
    short_run_name: false, # If true, use simple run_names like v_id_1
    no_repo: true, # Disable CodeRunner repo, true for now as in development
    simple_prompt: false, # If true have a less fancy prompt in interactive mode
    non_interactive: false, # If true, don't prompt for feedback when executing commands. Use with caution.
    launcher: nil, # To activate the launcher, set this to be a string. The launcher will use the folder ~/.coderunner/to_launch/GLOBAL_OPTIONS[:launcher]
  }

  class CodeRunner::ConfigError < StandardError
  end


  def self.global_options(option)
    raise CodeRunner::ConfigError.new(
      "Missing value for global option #{option.inspect}. Global options are #{GLOBAL_OPTIONS.inspect}."
    ) unless GLOBAL_OPTIONS.keys.include?(option)
    return GLOBAL_OPTIONS[option]
  end


  CONFIG_FOLDER = ENV['HOME'] + "/.coderunner"
  CONFIG_FILE = CONFIG_FOLDER + '/config.rb'
  #Create the coderunner config directory if it doesn't exist
  FileUtils.makedirs(CONFIG_FOLDER)
  COMMAND_FOLDER = Dir.pwd
  SCRIPT_FOLDER = File.dirname(File.expand_path(__FILE__))  #i.e. where this script is


  if FileTest.exist? CONFIG_FILE
    load CONFIG_FILE
  end
  # Deprecated as insecure
  if ENV['CODE_RUNNER_OPTIONS']
    $stderr.puts 'WARNING: CODE_RUNNER_OPTIONS is insecure and deprecated. Please use ~/.coderunner/config instead'
    begin
      env_global_options = eval(ENV['CODE_RUNNER_OPTIONS']) # global options are set by the environment but some can be changed.
      env_global_options.each{|k,v| GLOBAL_OPTIONS[k] = v}
    rescue
      raise CodeRunner::ConfigError.new("Environment variable CODE_RUNNER_OPTIONS is not a valid hash")
    end
  end
  GLOBAL_OPTIONS.keys.each do |key|
    env_string = 'CODE_RUNNER_' + key.to_s.upcase
    if env_val = ENV[env_string]
      GLOBAL_OPTIONS[:key] = 
        case env_val
        when 'true'
          true
        when 'false'
          false
        when /\d+/
          env_val.to_i
        when /\d[\deE+-\.]*/
          env_val.to_f
        else
          env_val
        end
    end
  end

  SYS = GLOBAL_OPTIONS[:system]
  require SCRIPT_FOLDER + "/system_modules/#{SYS}.rb"
  SYSTEM_MODULE = const_get(SYS.variable_to_class_name)
  include SYSTEM_MODULE
  class << self
    include SYSTEM_MODULE
  end
  @@sys = SYS
  def gets #No reading from the command line thank you very much!
    $stdin.gets
  end
  def self.gets
    $stdin.gets
  end

  #CodeRunner::CODE_RUNNER_VERSION = Version.new(Gem.loaded_specs['coderunner'].version.to_s) rescue "test"
  CodeRunner::CODE_RUNNER_VERSION = Version.new(File.read(SCRIPT_FOLDER + '/../../VERSION')) rescue "test"

end
