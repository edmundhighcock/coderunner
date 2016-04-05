require 'git'
class CodeRunner
  def is_in_repo?(folder=@root_folder)
    if CodeRunner.global_options(:no_repo)
      return false
    else
      Repository.repo_folder(folder) ?  true : false
    end
  end
  class Run
    # Add CodeRunner files within the run folder to git. If
    # the run_class for this run defines the run class property
    # repo_file_match, also add any files which match any of 
    def add_to_repo
      Dir.chdir(@directory) do
        repo = Repository.open_in_subfolder
        repo.add("code_runner_info.rb")
        repo.add("code_runner_results.rb")
        Dir.entries.each do |f|
          repo.add(f) if rcp.repo_file_match? and f =~ rcp.repo_file_match
        end
        repo.autocommit("Submitted simulation id #{id} in folder #{repo.relative_path(@runner.root_folder)}")
      end
    end
    def commit_results
      Dir.chdir(@directory) do
        repo = Repository.open_in_subfolder
        repo.add("code_runner_results.rb")
        Dir.entries.each do |f|
          repo.add(f) if rcp.repo_file_match? and f =~ rcp.repo_file_match
        end
        repo.autocommit("Updated results for id #{id} in folder #{repo.relative_path(@runner.root_folder)}") if repo.changed_in_folder(@directory).size > 0
      end
    end
  end
  # This is a class which implements methods 
  # for managing a CodeRunner repository, which is a
  # slightly customised git repository. It contains 
  # methods for initializing standard files, and maintains
  # a small amount of metadata about the repository.
  # In addition, every clone of coderunner repository
  # comes in a pair: one bare repository, and one local 
  # repository, which is a clone of the bare repository.
  # This allows easy synchronisation of working directories
  # without the need for a central server which all 
  # working directories have access to.
  class Repository < Git::Base
    def self.url_regex
      (/(?:ssh:\/\/)?(?<namehost>[^\/:]+):?(?<folder>.*$)/)
    end
    def self.bare_ext_reg
      /\.cr\.git$/
    end
     
    # Create a coderunner repo, which consists of a
    # twin set of a bare repo and a clone of that
    # repo. folder must end in '.cr.git'
    #
    class << self
      alias :simple_init :init
      def init(folder)
        if folder =~ /\.git$/
          raise "Please do not add '.git' to the end of #{folder}. Two repositories will be created: a bare repo ending in .cr.git and a clone of this bare repo"
        end
        super(bflocal = folder + '.cr.git', bare: true, repository: bflocal)
        repo = simple_clone(bflocal, folder)
        repo.init_metadata
        repo.init_readme
        repo.init_defaults_folder
        p 'remotes', repo.remotes.map{|r| r.name}
        repo.simple_push(repo.remote("origin"))
      end
      alias :simple_clone :clone
      def clone(url, name)
        namehost, folder, _barefolder = split_url(url)
        try_system %[ssh #{namehost} "cd #{folder} && git push origin"]
        simple_clone(url, bflocal=name+'.cr.git', bare: true, repository: bflocal)  
        return simple_clone(bflocal, name)  
      end
    end

    # If the folder is within a coderunner repository
    # return the root folder of the repository; else 
    # return nil
    def self.repo_folder(folder = Dir.pwd)
      f2 = File.expand_path(folder)
      while not (Dir.entries(f2).include?('.git') and 
            Dir.entries(f2).include?('.code_runner_repo_metadata'))
        f2 = File.expand_path(f2 + '/..')
        (f2=nil; break) if f2 == '/' 
        #p 'f2 is ', f2
      end
      return f2
    end
    # Open a git object from within a subfolder of a repository
    # Checks to see if the subfolder actually is inside a CodeRunner
    # repository.
    def self.open_in_subfolder(folder = Dir.pwd)
      f2 = repo_folder(folder)
      raise "#{folder} is not a coderunner repository " if not f2
      return open(f2)
    end
    # Returns a Git::Base object referring to the bare twin 
    # repository.
    def bare_repo
      #puts 'bare_repo', dir.to_s + '.cr.git'
      @bare_repo ||= Git::Base.bare(dir.to_s + '.cr.git')
    end
    def relative_path(folder=Dir.pwd)
      File.expand_path(folder).sub(File.expand_path(dir.to_s) + '/', '')
    end
    def repo_file(path)
      "#{dir}/#{path}"
    end
    def init_readme
      File.open(repo_file("README.md"), "w"){|f| f.puts readme_text}
      add(repo_file("README.md"))
      autocommit_all('Added README.md')
    end
    def init_metadata
      Hash.phoenix(repo_file('.code_runner_repo_metadata')) do |hash|
        hash[:creation_time] = Time.now.to_i
        hash[:autocommit] = true
      end
      add(repo_file('.code_runner_repo_metadata'))
      autocommit_all('Added metadata')
    end
    def metadata
      Hash.phoenix(repo_file('.code_runner_repo_metadata'))
    end
    def add_folder(folder)
      Dir.chdir(folder) do
        require 'find'
        #files = []
        Find.find('.') { |e| (puts e; add(e)) if
          e =~ /code_runner_info.rb/ or
          e =~ /code_runner_results.rb/ or 
          e =~ /.code-runner-irb-save-history/ or
          e =~ /.code_runner_script_defaults.rb/ or
          (Dir.entries(Dir.pwd).include?('.code_runner_script_defaults') and
           (repo_file_match = (
             rcp = CodeRunner.fetch_runner(Y: folder, U: true).run_class.rcp; 
             rcp.repo_file_match? ? rcp.repo_file_match : false); 
             repo_file_match =~ m
           )
          )
        }
      end
      autocommit_all("Added folder #{relative_path(folder)}")
    end
    def autocommit(*args)
      commit(*args) if metadata[:autocommit]
    end
    def autocommit_all(*args)
      commit_all(*args) if metadata[:autocommit]
    end
    def init_defaults_folder
      FileUtils.makedirs(repo_file("defaults_files"))
      File.open(repo_file("defaults_files/README"), "w"){|f|
         f.puts  <<EOF
This folder is where defaults files for codes should be placed, with
paths such as defaults_files/<code>crmod/my_defaults.rb. This folder 
will automatically be checked for defaults files when submitting simulations
within this repository.
EOF
      
      }
      add(repo_file("defaults_files/README"))
      autocommit_all('Added defaults folder')
    end
    def readme_text
      return <<EOF
#{File.basename(dir.path)} CodeRunner Repository
================================================

This is a coderunner repository, which consists of
a managed set of simulation folders and defaults files which are 
synchronised across systems using git. 

This readme is a stub which was created automatically...
feel free to modify this and describe this repo.

Created on: #{Time.now.to_s}

EOF
    end
    def self.split_url(url)
      url =~ Repository.url_regex
      namehost = $~[:namehost]
      barefolder = $~[:folder]
      check_bare_ext(barefolder)
      folder = barefolder.sub(/\.cr\.git$/, '')
      return [namehost, folder, barefolder]
    end
    def split_url(remote_name)
      return self.class.split_url(bare_repo.remote(remote_name).url)
    end
    def modified_in_folder(folder)
      (status.changed + status.added + status.deleted).find_all{|k,f| File.expand_path(dir.to_s + '/' + f.path).include?(File.expand_path(folder))}
    end
    alias :changed_in_folder :modified_in_folder
    def deleted_in_folder(folder)
      (status.deleted).find_all{|k,f| File.expand_path(dir.to_s + '/' + f.path).include?(File.expand_path(folder))}
    end
    def modified?(file)
      (status.changed + status.added).find{|k,f| File.expand_path(dir.to_s + '/' + f.path).include?(File.expand_path(file))}
    end
    # Bring all files in the given folder from 
    # the given remote. (Obviously folder must 
    # be a subfolder within the repository).
    def rsyncd(remote_name, folder)
      namehost, remote_folder, _barefolder = split_url(remote_name)
      rpath = relative_path(folder)
      if File.expand_path(folder) == File.expand_path(dir.to_s)
        raise "Cannot run rsyncd in the top level of a repository"
      end 
      string =  "rsync -av #{namehost}:#{remote_folder}/#{rpath}/ #{folder}/"
      if changed_in_folder(folder).size > 0
        raise "You have some uncommitted changes in the folder #{folder}. Please commit these changes before calling rsyncd"
      end
      puts string
      system string
    end
    # Send all files in the given folder to 
    # the given remote. (Obviously folder must 
    # be a subfolder within the repository).
    def rsyncu(remote_name, folder)
      namehost, remote_folder, _barefolder = split_url(remote_name)
      rpath = relative_path(folder)
      if File.expand_path(folder) == File.expand_path(dir.to_s)
        raise "Cannot run rsyncd in the top level of a repository"
      end 
      string =  "rsync -av  #{folder}/ #{namehost}:#{remote_folder}/#{rpath}/"

      cif = `ssh #{namehost} "cd #{remote_folder}/#{rpath} && echo "START" && git status"`
      if cif =~ /START.*modified/m
        raise "You have some uncommitted changes in the remote folder #{rpath}. Please commit these changes before calling rsyncu"
      end
      puts string
      system string
    end
    
    def add_remote(name, url)
      url =~ Repository.url_regex
      barefolder = $~[:folder]
      unless barefolder =~ Repository.bare_ext_reg
        raise "All remotes must end in .cr.git for coderunnerrepo"
      end
      super(name, url)
    end

    # Check that barefolder ends in .cr.git
    def self.check_bare_ext(barefolder)
      unless barefolder =~ bare_ext_reg
        raise "Remotes must end in .cr.git for coderunnerrepo"
      end
    end

    def bare_ext_reg
      self.class.bare_ext_reg
    end

    alias :simple_pull :pull

    # Pull from the given remote object. remote must be a remote
    # object from the twin bare repo, i.e. a member of bare_repo.remotes
    # NOT a remote from the coderunner repo (which only ever has
    # one remote: origin, corresponding to the bare repo).
    def pull(remote)
      namehost, folder, _barefolder = split_url(remote.name)
      try_system %[ssh #{namehost} "cd #{folder} && git push origin"]
      Dir.chdir(bare_repo.repo.to_s) do
        try_system("git fetch #{remote.name} master:master")
      end
      #bare_repo.fetch(remote)
      simple_pull(remote('origin'))
    end
    # A simple git push... does not try to push to local 
    # bare repo or pull remote working repos
    alias :simple_push :push

    # Push to the given remote object. remote must be a remote
    # object from the twin bare repo, i.e. a member of bare_repo.remotes
    # NOT a remote from the coderunner repo (which only ever has
    # one remote: origin, corresponding to the bare repo).
    #
    # First push to the bare '.git' twin repo, then push that
    # bare repo to the remote, then pull remote repos from the 
    # remote bare repos.
    def push(remote)
      namehost, folder, _barefolder = split_url(remote.name)
      puts 'simple_push'
      simple_push(remote('origin'))
      puts 'bare_repo.push'
      bare_repo.push(remote)
      try_system %[ssh #{namehost} "cd #{folder} && git pull origin"]
    end
    def try_system(str)
      RepositoryManager.try_system(str)
    end
    def self.try_system(str)
      RepositoryManager.try_system(str)
    end
  end

end
