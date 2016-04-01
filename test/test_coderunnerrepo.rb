
require 'helper'
require 'rbconfig'
require 'coderunner/repository_manager'

unless $cpp_command = ENV['CPP']
	raise "Please specify the environment variable CPP (the C++ compiler)"
end
$coderunner_folder = File.dirname(File.expand_path(__FILE__)) + '/../'

module MiniTest::Assertions
	def assert_system(string)
		assert(system(string), "System Command: '#{string}'")
	end
end

$ruby_command = "#{RbConfig::CONFIG['bindir']}/#{RbConfig::CONFIG['ruby_install_name']}"
$coderunnerrepo_command = "#{$ruby_command}  -I #{$coderunner_folder}lib/ #{$coderunner_folder}/lib/coderunner/repository_manager.rb"

class Dummy
  include CodeRunner::InteractiveMethods
end
class TestCreate < MiniTest::Test
  def tfolder
    'test/createrepo'
  end
  def dffolder
    'myrepo/crdummyfiles'
  end
  def setup
    FileUtils.rm_r(tfolder) if FileTest.exist? tfolder
    FileUtils.makedirs(tfolder)
		string = $cpp_command + ' ../cubecalc.cc -o cubecalc'
		Dir.chdir('test'){CodeRunner.generate_cubecalc}
		Dir.chdir(tfolder){assert_system string; FileUtils.rm('../cubecalc.cc')}
  end
  def test_create
    Dir.chdir(tfolder) {

      assert_system("#$coderunnerrepo_command init myrepo")
      assert_system("#$coderunnerrepo_command adrm local ssh://#{ENV['USER']}@localhost/#{Dir.pwd}/remote.cr.git -Y myrepo")
      assert_system("#$coderunnerrepo_command adrm dummy ssh://dummyuser@nohost/#{Dir.pwd}/remote.cr.git -Y myrepo")
      assert_system("#$coderunnerrepo_command pushcr -r local -Y myrepo")
      assert_system("cd myrepo.cr.git; git remote rm dummy")
      assert_system("#$coderunnerrepo_command pull -Y myrepo")
      assert_system("#$coderunnerrepo_command push -Y myrepo")
      FileUtils.makedirs(dffolder)
      FileUtils.touch(dffolder + '/code_runner_info.rb')
      FileUtils.touch(dffolder + '/code_runner_results.rb')
      CodeRunner::RepositoryManager.add_folder('myrepo/crdummyfiles', {})
      FileUtils.makedirs('myrepo/sims')
      Dir.chdir('myrepo/sims') do
        CodeRunner.submit(C: 'cubecalc', m: 'empty', X: '../../cubecalc')
        CodeRunner.submit(C: 'cubecalc', m: 'empty', X: '../../cubecalc')
        FileUtils.touch('.code-runner-irb-save-history')
        Dummy.new.setup_interactive
      end
      CodeRunner::RepositoryManager.remote_synchronize_up('local', 'myrepo/sims', {})
      CodeRunner::RepositoryManager.remote_synchronize_down('local', 'myrepo/sims', {})
      Dir.chdir('remote') do
        FileUtils.makedirs 'sims'
        Dir.chdir('sims') do
          system "echo 'Hello' >> dummyfile"
          system "git add dummyfile"
          system "git commit -m 'added dummyfile'"
          system "echo 'Hello' >> dummyfile"
        end
        #add('dummyfile')
      end
      err = assert_raises(RuntimeError){CodeRunner::RepositoryManager.remote_synchronize_up('local', 'myrepo/sims', {})}
      p err.message
      Dir.chdir('remote') do
        Dir.chdir('sims') do
          system "git add dummyfile"
          system "git commit -m 'modified dummyfile'"
        end
      end
      Dir.chdir('myrepo/sims') do
        system "echo 'Hello' >> dummyfile"
        system "git add dummyfile"
        system "git commit -m 'added dummyfile'"
        system "echo 'Hello' >> dummyfile"
      end
      err = assert_raises(RuntimeError){CodeRunner::RepositoryManager.remote_synchronize_down('local', 'myrepo/sims', {})}
      p err.message
      FileUtils.makedirs('testclone')
      assert_system("#$coderunnerrepo_command clone ssh://#{ENV['USER']}@localhost/#{Dir.pwd}/remote.cr.git myclone -Y testclone")
      CodeRunner::RepositoryManager.push_repository(r: 'origin', Y: 'testclone/myclone')
    }
  end
  def teardown
    FileUtils.rm_r(tfolder)
  end
end
