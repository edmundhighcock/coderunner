class CodeRunner

  module InteractiveMethods
    COMMANDS.each do |command|
      eval("def #{command[1]}(*args) 
#            if args[-1].kind_of? 
          CodeRunner.send(#{command[0].to_sym.inspect}, *args)
            end")
    end
    def up
      ObjectSpace.each_object{|obj| obj.update if obj.class.to_s =~ /CodeRunner$/}
      nil
    end
    def cd(dirct)
      Dir.chdir(dirct)
    end
    def setup_interactive
      @runner = CodeRunner.fetch_runner(CodeRunner::DEFAULT_COMMAND_OPTIONS.dup) unless CodeRunner::DEFAULT_COMMAND_OPTIONS[:q]
      @r = @runner
      if @r
        histfile = @r.root_folder + '/.code-runner-irb-save-history'
        if FileTest.exist?(histfile)
          if @r.is_in_repo?
            repo = Repository.open_in_subfolder(@r.root_folder)
            repo.add(histfile)
            repo.autocommit("Updated save history in #{repo.relative_path(@r.root_folder)}") if repo.modified? histfile
          end
        end
      end

    end
    def pwd
      puts Dir.pwd
    end
    def runs
      CodeRunner.runner.run_list
    end
    # Change the default root folder(s) for commands. If a runner
    # has not been loaded for a given folder, it will be loaded
    # as subsequently required.
    def change_root_folder(folder)
      DEFAULT_COMMAND_OPTIONS[:Y] = folder
    end
    alias :crf :change_root_folder





    INTERACTIVE_METHODS = <<EOF
include CodeRunner::InteractiveMethods
setup_interactive
EOF

  end # module InteractiveMethods

  def CodeRunner.interactive_mode(copts={})
    process_command_options(copts)
    File.open(".int.tmp.rb", 'w')do |file|
      file.puts "#{copts.inspect}.each do |key, val|
          CodeRunner::DEFAULT_COMMAND_OPTIONS[key] = val
        end"
      file.puts CodeRunner::InteractiveMethods::INTERACTIVE_METHODS
    end
    exec %[#{RbConfig::CONFIG['bindir']}/irb#{RbConfig::CONFIG['ruby_install_name'].sub(/ruby/, '')} -f -I '#{Dir.pwd}' -I '#{SCRIPT_FOLDER}'   -I '#{ENV['HOME']}'  -r 'coderunner/config' -r 'coderunner/interactive_config' -r 'coderunner' -r .int.tmp ]
  end


end


require "readline"


module IRB

  COMMANDS = ENV['PATH'].split(':').inject([]) do |comms,dir|
    #     ep dir
    begin
      dir = dir.sub(/~/, ENV['HOME'])
      Dir.entries(dir).each do |file|
        file = "#{dir}/#{file}"
        #       ep file
        comms.push(File.basename(file)) if FileTest.executable? file #and File.file? file
      end
    rescue
    end
    comms
  end
  COMMANDS.delete_if{|com| com =~ /^\./}
  #   ep 'COMMANDS', COMMANDS

  module InputCompletor

    def self.complete_files(receiver, message)
      #       files = message.split(/\s+/)
      #       message = files.pop
      dir = message.sub(/[^\/]*$/, '')
      message = message.sub(Regexp.new("#{Regexp.escape(dir)}"), '')
      dir.sub!(/^~/, ENV['HOME'])
      short_dir = dir
      dir = Dir.pwd + '/' + dir unless dir =~ /^\//
      #$stderr.puts "Dir to scan: #{dir}"

      files = Dir.entries(dir)

      #$stderr.puts "entries", files
      Dir.chdir(dir){files= files.map{|file| FileTest.directory?(file) ? file + "/" : file}}
      #$stderr.puts "entries - directories", files

      candidates = message.size > 0 ? files.find_all{|com| com[0...message.size] == message} : files
      return candidates.map{|com| receiver + short_dir + com}
    rescue 
      return []
    end

    @RCS_ID='-$Id: completion.rb 23233 2009-04-19 13:35:47Z yugui $-'


    CodeRunnerCompletionProc = proc do |input|
      bind = IRB.conf[:MAIN_CONTEXT].workspace.binding
      Readline.completion_append_character = nil
      #     eputs "\n\ninput: #{input}"


      case input
      when Regexp.new("^(#{/\w+\b.*(?:\s|,)(?::p\s+\=\>|p:)\s+\[?\s*/}(?:#{Regexp.quoted_string}\\s*,\\s*)*#{/'\{(?:[^}]*\s)?:?/})(\\w+)$")
        # matches CodeRunner parameter list.... command [stuff] p: '{var: value, var
                                                                                                             receiver = $1
        message = $2
        #         ep 'mess', message
        if CodeRunner.runner and CodeRunner.runner.run_class
          candidates = CodeRunner.runner.run_class.rcp.variables.map{|var| var.to_s}.find_all{|var| var[0...message.size] == message}.map{|var| receiver + var}
        else
          candidates = []
        end
      when /^('(?:(?:\\ |[^'\s])*\s+)*)((?:\\ |[^'\s])*)$/, Regexp.new("^((?:[^']|#{Regexp.quoted_string})*')([^']*)$")
        #filename in a single quoted string
        receiver = "#$1" # "`" #$~[1]
        message = "#$2" #Regexp.quote($~[2]) # $2 #Regexp.quote($2)
        #       ep 'mess', message
        complete_files(receiver, message)



      when /^(\`\w+\s+(?:\S+\s+)*)([^`\s]*)$/, /^([^`]*`\w+\s+)([^`]*)$/
        #shell command with an executable
        receiver = $1 # "`" #$~[1]
        message = $2 #Regexp.quote($~[2]) # $2 #Regexp.quote($2)
        complete_files(receiver, message)
        #       files = Dir.entries(File.dirname(message))
        #       candidates = message.size > 0 ? files.find_all{|com| com[0...message.size] == message} : files
        #       candidates.map{|com| receiver + com}

      when /^(\`)([^`]*)$/, /^([^`]*`)([^`]*)$/
        #shell command without an excutable

        #         p $~
        receiver = $1 # "`" #$~[1]
        message = $2 #Regexp.quote($~[2]) # $2 #Regexp.quote($2)
        #   ep "message is", message
        #   ep COMMANDS.grep(//)
        candidates = message.size > 0 ? COMMANDS.find_all{|com| com[0...message.size] == message} : COMMANDS
        candidates.map{|com| receiver + com}
        #.grep(Regexp.new("^#{message}")) #("^#{Regexp.escape(message)}")) #.map{|com| "#{com}"} #.map{|com| receiver + com}
        #   ep candidates
        #   select_message(receiver, message, COMMANDS)

      when /^([^\/]*\/[^\/]*\/)\.([^.]*)$/
        # Regexp
        receiver = $1
        message = Regexp.quote($2)

        candidates = Regexp.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      when /^([^\]]*\])\.([^.]*)$/
        # Array
        receiver = $1
        message = Regexp.quote($2)

        candidates = Array.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      when /([^\}]*\})\.([^.]*)$/
        # Proc or Hash
        receiver = $1
        message = Regexp.quote($2)

        candidates = Proc.instance_methods.collect{|m| m.to_s}
        candidates |= Hash.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)


      when /^((?:(::)?[A-Z][^:.(]*)+)\.help :(\w*)$/
        # CodeRunner help method
        receiver = $1
        message = Regexp.quote($3)
        begin
          candidates = eval("(#{receiver}.constants - Object.constants).collect{|m| m.to_s}", bind)
          candidates |= eval("(#{receiver}.methods - Object.methods).collect{|m| m.to_s}", bind)
          begin
            candidates |= eval("(#{receiver}.instance_methods - Object.instance_methods).collect{|m| m.to_s}", bind)
          rescue
          end
        rescue Exception
          candidates = []
        end
        candidates.grep(/^#{message}/).collect{|e| receiver + '.help :' + e}

      when /^((?:.*[^:])?:[^:.]*)$/
        #         eputs 'found symbol'
        # Symbol
        if Symbol.respond_to?(:all_symbols)
          sym = $1
          candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}
          candidates.grep(/^#{sym}/)
        else
          []
        end

      when /^(.*\s)?(((::)?[A-Z][^:.(]*)+)(::|\.)([^:.]*)$/
        # Constant or class methods
        #         p "CCC"
        start = $1
        receiver = $2
        message = Regexp.quote($6)
        joiner = "#$5"
        begin
          candidates = eval("#{receiver}.constants.collect{|m| m.to_s}", bind)
          candidates |= eval("#{receiver}.methods.collect{|m| m.to_s}", bind)
        rescue Exception
          candidates = []
        end
        candidates.grep(/^#{message}/).collect{|e| (start or "") + receiver + (joiner or "::") + e}


      when /^(.*)(\b[A-Z][^:\.\(]*)$/
        # Absolute Constant or class methods
        receiver = $1
        message = $2
        candidates = Object.constants.collect{|m| m.to_s}
        candidates.grep(/^#{message}/).collect{|e| receiver + e}



      when /^(.*-?(0[dbo])?[0-9_]+(\.[0-9_]+)?([eE]-?[0-9]+)?)\.([^.]*)$/
        # Numeric
        receiver = $1
        message = Regexp.quote($5)

        begin
          candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
        rescue Exception
          candidates = []
        end
        select_message(receiver, message, candidates)

      when /^(.*-?0x[0-9a-fA-F_]+)\.([^.]*)$/
        # Numeric(0xFFFF)
        receiver = $1
        message = Regexp.quote($2)

        begin
          candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
        rescue Exception
          candidates = []
        end
        select_message(receiver, message, candidates)

      when /^(.*[\s\{\[])?(\$[^.]*)$/
        regmessage = Regexp.new(Regexp.quote($1))
        candidates = global_variables.collect{|m| m.to_s}.grep(regmessage)

        #      when /^(\$?(\.?[^.]+)+)\.([^.]*)$/
      when /^((\.?[^.]+)+)\.([^.]*)$/
        # variable
        receiver = $1
        message = Regexp.quote($3)

        gv = eval("global_variables", bind).collect{|m| m.to_s}
        lv = eval("local_variables", bind).collect{|m| m.to_s}
        cv = eval("self.class.constants", bind).collect{|m| m.to_s}

        if (gv | lv | cv).include?(receiver)
          # foo.func and foo is local var.
          candidates = eval("#{receiver}.methods", bind).collect{|m| m.to_s}
        elsif /^[A-Z]/ =~ receiver and /\./ !~ receiver
          # Foo::Bar.func
          begin
            candidates = eval("#{receiver}.methods", bind).collect{|m| m.to_s}
          rescue Exception
            candidates = []
          end
        else
          # func1.func2
          candidates = []
          ObjectSpace.each_object(Module){|m|
            begin
              name = m.name
            rescue Exception
              name = ""
            end
            next if name != "IRB::Context" and 
              /^(IRB|SLex|RubyLex|RubyToken)/ =~ name
            candidates.concat m.instance_methods(false).collect{|x| x.to_s}
          }
          candidates.sort!
          candidates.uniq!
        end
        select_message(receiver, message, candidates)

      when /^\.([^.]*)$/
        # unknown(maybe String)

        receiver = ""
        message = Regexp.quote($1)

        candidates = String.instance_methods(true).collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      else
        candidates = eval("methods | private_methods | local_variables | self.class.constants", bind).collect{|m| m.to_s}

        (candidates|ReservedWords).grep(/^#{Regexp.quote(input)}/)

      end
    end

  end

  def self.select_message(receiver, message, candidates)
    candidates.grep(/^#{message}/).collect do |e|
      if receiver =~ /^.*`/
        receiver + e
      else
        case e
        when /^[a-zA-Z_]/
          receiver + "." + e
        when /^[0-9]/
        when *Operators


          #receiver + " " + e
        end
      end
    end
  end
  class InputMethod
  end
  class ReadlineInputMethod < InputMethod
    include Readline 
    def gets
      Readline.input = @stdin
      Readline.output = @stdout
      prompt_end = Time.now.to_s[11...16]
      begin
        memsize = `ps ax -o pid,rss | grep -E "^[[:space:]]*#{Process::pid}"`.chomp.split(/\s+/).map {|s| s.strip.to_i}[1].to_i/1000
        prompt_end += " #{memsize}k"
      rescue
      end
      prompt_end +=" (#{CodeRunner::SETUP_RUN_CLASSES.join(",")})"
      if l = readline(@prompt.gsub(/timemarker/, prompt_end) , false)
        #HISTORY.push(l) if !l.empty? and (HISTORY.size ==0 or l != HISTORY[-1])
        HISTORY.push(l) if !l.empty? and (HISTORY.size ==0 or l != HISTORY[-1])

        i = 0
        loop do
          break if HISTORY.size == 1
          (HISTORY.delete_at(i); i-=1) if HISTORY[i] == l
          i+=1
          #ep "i: #{i}, HS: #{HISTORY.size}"
          break if i >= HISTORY.size - 1
        end
        #HISTORY.reverse!
        #HISTORY.uniq!
        #HISTORY.reverse!
        #HISTORY.push(l) if !l.empty? and (HISTORY.size ==0 or !HISTORY.include? l)
        @line[@line_no += 1] = l + "\n"
      else
        @eof = true
        l
      end
    end
  end

end #module IRB

if Readline.respond_to?("basic_word_break_characters=")
  Readline.basic_word_break_characters= "\t\n><=;|&("
end
Readline.completion_append_character = "BB"
Readline.completion_proc = IRB::InputCompletor::CodeRunnerCompletionProc

begin
  if Readline.respond_to?("basic_quote_characters=")
    Readline.basic_quote_characters= "\"'`"
  end
rescue NotImplementedError
end

module Kernel

end

require 'rdoc'
require 'rdoc/ri/driver'

class Object
  def self.help(meth_or_const=nil)
    join = ""
    if meth_or_const
      if self.constants.include? meth_or_const.to_sym
        join = "::"
      elsif self.methods.include? meth_or_const.to_sym
        join = "."
      elsif self.instance_methods.include? meth_or_const.to_sym
        join = "#"
      end
    end
    CodeRunner.reference("#{self.to_s}#{join}#{meth_or_const}")
  end
end

class Module

  def help(meth_or_const=nil)
    join = ""
    if meth_or_const
      if self.constants.include? meth_or_const.to_sym
        join = "::"
      elsif self.methods.include? meth_or_const.to_sym
        join = "."
      elsif self.instance_methods.include? meth_or_const.to_sym
        join = "#"
      end
    end
    CodeRunner.reference("#{self.to_s}#{join}#{meth_or_const}")
  end
end
