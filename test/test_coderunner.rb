if true
require 'helper'
require 'rbconfig'
CodeRunner::RemoteCodeRunner::DISPLAY_REMOTE_INVOCATION = true

module MiniTest::Assertions
	def assert_system(string)
		assert(system(string), "System Command: '#{string}'")
	end
end

unless $cpp_command = ENV['CPP']
	raise "Please specify the environment variable CPP (the C++ compiler)"
end

$ruby_command = "#{RbConfig::CONFIG['bindir']}/#{RbConfig::CONFIG['ruby_install_name']}"
$coderunner_command = "#{$ruby_command}  -I lib/ lib/coderunner.rb"

#Dir.chdir('test') do 
	#raise "Couldn't build test program using #{string}" unless system string
#end

if true
class TestSubmission  < MiniTest::Test
	def setup
		string = $cpp_command + ' ../cubecalc.cc -o cubecalc'
		Dir.chdir('test'){CodeRunner.generate_cubecalc}
		FileUtils.makedirs('test/submission_results')
		Dir.chdir('test/submission_results'){assert_system string}
		CodeRunner.setup_run_class('cubecalc', modlet: 'sleep')
	end
	def test_setup_run_class
		assert(CodeRunner::Cubecalc::Sleep.ancestors.include?(CodeRunner::SYSTEM_MODULE), "CodeRunner::Cubecalc.ancestors.include? CodeRunner::SYS, ancestors: #{CodeRunner::Cubecalc.ancestors}")
		assert(CodeRunner::Cubecalc::Sleep.rcp.user_defaults_location?, "CodeRunner::Cubecalc::Sleep.rcp.user_defaults_location? #{CodeRunner::Cubecalc::Sleep.rcp.user_defaults_location?}")
		assert_equal(ENV['HOME'] + '/.coderunner/cubecalccrmod/defaults_files', CodeRunner::Cubecalc::Sleep.rcp.user_defaults_location)
	end
	def test_submission
		CodeRunner.submit(Y: 'test/submission_results', C: 'cubecalc', m: 'empty', X: Dir.pwd + '/test/submission_results/cubecalc', p: %|{extra_files: ["#{Dir.pwd}/test/test_coderunner.rb"]}|)
		CodeRunner.status(Y: 'test/submission_results')
		assert(FileTest.exist?('test/submission_results/v'))
		assert(FileTest.exist?('test/submission_results/v/id_1'))
		assert(FileTest.exist?('test/submission_results/v/id_1/test_coderunner.rb'))
		assert(FileTest.exist?('test/submission_results/cubecalc_defaults.rb'))
	end
	def test_status_loop
		unless ENV['SHORT_TEST']
			CodeRunner::GLOBAL_OPTIONS[:launcher] = '42323490qw4q4432407Q2342U3'
			#@mutex = Mutex.new
			#@launcher_started =
			@thread = Thread.new{CodeRunner.start_launcher(0.5,10)}
			sleep 0.1 while not FileTest.exist?(CodeRunner.launcher_directory)
			CodeRunner.submit(Y: 'test/submission_results', C: 'cubecalc', m: 'sleep', X: Dir.pwd + '/test/submission_results/cubecalc', p: '{sleep_time: 2}')
			CodeRunner.status_loop(Y: 'test/submission_results')
			#@thread.kill # This is commented out because it causes a Heisenbug... the kill signal can get trapped and cause the deletion of the 'submitting' lock file. This line is unnecessary because the thread will die when the program exits
      CodeRunner::GLOBAL_OPTIONS[:launcher] = nil
		end
	end
	def testanalysis
		CodeRunner.submit(Y: 'test/submission_results', C: 'cubecalc', m: 'empty', X: Dir.pwd + '/test/submission_results/cubecalc', p: '{width: 2.0, height: 3.0}')
		runner = CodeRunner.fetch_runner(Y: 'test/submission_results')
		#system "ps"
		runner.update
		runner.print_out(0)
		assert_equal(6.0, runner.run_list[1].volume)
	end
	def test_command_line_submission
	   assert_system("#{$ruby_command}  -I lib/ lib/coderunner.rb submit -C cubecalc -m sleep -D sleep -X #{Dir.pwd}/test/submission_results/cubecalc -Y test/submission_results")
	end
	def test_manual
		#CodeRunner.manual
	end
	def teardown
		FileUtils.rm_r('test/submission_results')
		FileUtils.rm_r('test/cubecalc.cc')
	end
end


class TestCodeRunner < MiniTest::Test
	
	# Override this method as we want the tests to be run in the order they are defined
	
	#def self.test_methods
				#public_instance_methods(true).grep(/^test/).map { |m| m.to_s}
	#end
	
	def setup
		FileUtils.makedirs('test/results')
		string = $cpp_command + ' ../cubecalc.cc -o cubecalc'
		Dir.chdir('test'){CodeRunner.generate_cubecalc}
		Dir.chdir('test/results'){assert_system string}
		CodeRunner.submit(Y: tfolder, C: 'cubecalc', m: 'empty', X: Dir.pwd + '/test/results/cubecalc', T: true)
	# 	exit
		defs = File.read('test/results/cubecalc_defaults.rb')
		File.open('test/results/cubecalc_defaults.rb', 'w'){|f| f.puts defs.sub(/\#(@calculate_sides\s+=\s+)0/, '\11')}
		CodeRunner.submit(Y: Dir.pwd + '/test/results', p: ["{width: 3.0,  height: 8.0}", "{width: 3.0, height: 6.0}", "{width: 3.0,  height: 9.0}", "{width: 12.0,  height: 9.0}", "{width: 5.0,  height: 6.0}", "{width: 11.0, height: 9.0, depth: 2.0}"])
		@runner = CodeRunner.fetch_runner(Y: Dir.pwd + '/test/results').update		
	end
	
	def teardown
		FileUtils.rm_r('test/results')
		FileUtils.rm('test/cubecalc.cc')
	end

	def tfolder
		Dir.pwd + '/test/results'
	end
	def tfolder2
		Dir.pwd + '/test/results2'
	end
	
	#def cl(command)
		#Dir.chdir('results'){assert_system command}
	#end

	#def cl2(command)
		#Dir.chdir('results3'){assert_system command}
	#end

	
	#def cl3(command)
		#Dir.chdir('results3'){assert_system command}
	#end

	
	def test_remote_coderunner
		puts 'testing remote coderunner'
		rc = RemoteCodeRunner.new(ENV['USER'] + '@localhost', Dir.pwd + '/test/results', U: true, N: true).update
    p rc
		assert_equal(@runner.ids.sort, rc.ids.sort)
		rc.print_out(0)
		wdvh = rc.graphkit("width:height:depth:volume;;;volume")
		#wdvh.gnuplot
		assert_equal(4, wdvh.naxes)
		assert_equal(1, wdvh.data.size)
		assert_equal([18.0, 24.0, 27.0, 30.0, 108.0, 198.0], wdvh.data[0].axes[:f].data)
		_sds = rc.run_graphkit('sides;;[1,2].include? id')
		str = "A very very very looooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooonnnnnnnnnnnnnnnnnnnnnnnnnng string"
		str2 = rc.retrieve(str.inspect)
		assert_equal(str, str2)

# 		sds.gnuplot
		wdvh.close
		puts 'testing remote coderunner complete'
	end

	def test_available_defauls
		pipe = IO.popen("#$coderunner_command avd -Y test/results -C cubecalc -m empty")
		str = ""
	 	while line = pipe.gets
			str += line
		end	
		assert_match(/sleep/, str)
		assert_match(/cubecalc/, str)
		assert_match(/Available/, str)
		#STDIN.gets
	end
	
	def test_run_eval_saving
		puts "\nTesting run command saving"
		CodeRunner.run_command('@test_var = :will_o_the_wisp', Y: tfolder)
		@runner.update(false, true)
		assert_equal(:will_o_the_wisp, @runner.run_list[1].instance_variable_get(:@test_var))
		CodeRunner.run_command('@test_var2 = :will_o_the_wisps', Y: tfolder)
		
		@runner.update(false, true)
		assert_equal(:will_o_the_wisps, @runner.run_list[1].instance_variable_get(:@test_var2))
		puts 'finished testing run command saving'
	end
	
	def test_relative_directory
		puts "\nTesting relative directory"
		@runner.recalc_all = true
		puts 'updating fully'
		@runner.update #(true, false)
		FileUtils.rm_r(tfolder2) if FileTest.exist? tfolder2
		FileUtils.cp_r(tfolder, tfolder2)
		r = CodeRunner.fetch_runner(Y: tfolder2, U: true)
		r.update(false)
		assert_equal(tfolder, @runner.root_folder)
		assert_equal(tfolder2, r.root_folder)
		assert_equal(@runner.run_list[1].directory.sub(File.expand_path(@runner.root_folder) + '/', ''), r.run_list[1].relative_directory)
		assert_equal(r.root_folder + '/' + r.run_list[1].relative_directory, r.run_list[1].directory)
		FileUtils.rm_r tfolder2
	end
	
	def test_set_start_id_and_merged_code_runner
		eputs "\ntesting set_start_id"
		FileUtils.rm_r tfolder2 if FileTest.exist?(tfolder2)
		FileUtils.mkdir(tfolder2)
		#cl3('ruby ../../coderunner.rb st -C cubecalc -m empty -X ../cubecalc -T')
		#cl3("ruby ../../coderunner.rb ev 'set_start_id(20)'")
		#cl3('ruby ../../coderunner.rb sub -p "{width: 12.0, height: 9.0}"')
		CodeRunner.status(Y: tfolder2, C: 'cubecalc', m: 'empty', X: tfolder + '/cubecalc')
		CodeRunner.runner_eval('set_start_id(20)', Y: tfolder2)
		CodeRunner.submit(Y: tfolder2, p: "{width: 12.0, height: 9.0}")
		@runner3 = CodeRunner.new(tfolder2).update
		assert_equal(20, @runner3.start_id)
		assert_equal(21, @runner3.max_id)
		#eputs "\ntesting set_start_id complete"
		@runner3 = CodeRunner.new(tfolder2).update
		@mrunner = CodeRunner::Merged.new(@runner, @runner3)
		@mrunner.print_out(0)
    #STDIN.gets
		assert_equal(@runner.run_list.size + 1, @mrunner.run_list.size)
		@mrunner2 = @runner.merge(@runner3)
		assert_equal(@mrunner2.run_list.keys, @mrunner.run_list.keys)
    @mrunner.add_runner(@runner)
    assert_equal(CodeRunner::Run::Merged, @mrunner.run_list[[2, 6]].class)
    assert_equal(6, @mrunner.run_list[[2, 6]].run.id)
    assert_system("#$coderunner_command st -Y #{tfolder} -Y #{tfolder2}")
    assert_raises(RuntimeError){@mrunner.submit}
    #STDIN.gets
		FileUtils.rm_r tfolder2
	end
	
	def test_status_with_component
		CodeRunner.status(Y: tfolder, h: :c)
		CodeRunner.show_values_of('area', Y: tfolder, h: :c)
	end
	def test_alter_ids
		FileUtils.rm_r tfolder2 if FileTest.exist?(tfolder2)
		#FileUtils.mkdir(tfolder2)
		FileUtils.cp_r(tfolder, tfolder2)
		@runner4 = CodeRunner.new(tfolder2).update
		@runner4.alter_ids(40, no_confirm: true)
		@runner4a = CodeRunner.new(tfolder2).update
		assert_equal(@runner.ids.map{|id| id + 40}.sort, @runner4.ids.sort)
		assert_equal(@runner4a.ids.sort, @runner4.ids.sort)
		@runner4.alter_ids(40, no_confirm: true)
		@runner4a.update
		assert_equal(@runner.ids.map{|id| id + 80}.sort, @runner4.ids.sort)
		assert_equal(@runner4a.ids.sort, @runner4.ids.sort)
		run = @runner4.run_list.values[0]
		assert(FileTest.exist?(run.directory), "Run directory exists")
		ep run.id, 'id'
		#exit
		assert_equal(run.id, eval(File.read(run.directory + '/code_runner_info.rb'))[:id])
		FileUtils.rm_r tfolder2
	end
	
	#def test_submit_non_parallel_with_large_cache
		#FileUtils.touch('results/submitting')
## 		fork{cl('ruby ../../coderunner.rb sub -p "{width: 1.887, height: 9.0}"')}
		#fork{CodeRunner.submit(Y: 'results', p: "{width: 1.887, height: 9.0}", U: true)}
		#sleep 1.0
		#@runner.update(true, false)
		#assert_equal(0, @runner.run_list.values.find_all{|run| run.width==1.887}.size)
		#FileUtils.rm('results/submitting')
		#i = 0
		#Process.waitall
## 		(@runner.update(true, true); sleep 0.5; i+=1 ; flunk if i==20) until @runner.run_list.values.find{|run| run.width==1.887}
		#@runner.update(true, true)
		#assert_equal(1, @runner.run_list.values.find_all{|run| run.width==1.887}.size)
		#@runner.conditions = "id==7"
		#@runner.destroy(no_confirm: true)
		#assert_equal(0, @runner.run_list.values.find_all{|run| run.width==1.887}.size)
		#assert_raise(RuntimeError){CodeRunner.submit(Y: 'results', p: "{run_test_flags: {test_submit_error_handling: true}}", U: true)}
		#assert(!FileTest.exist?('results/submitting'))
	#end
	
	if ENV['LATEX']
	def test_latex_graphkit
		Dir.chdir('test/results') do
			#@runner.print_out(0)
			sds = @runner.run_graphkit('sides;;[1,2].include? id')
			#p sds
			sds.ylabel = 'Hello'
			sds.data.each_with_index{|dk,i| dk.title = i.to_s}
			sds.xlabel = '\(\Gamma_{\epsilon}\)'
			sds.title = 'Area of the Sides'
			#sds.gnuplot
			#pp sds
			#pid1 = sds.gnuplot

			sds.gnuplot_write('latgraph.eps', latex: true)
			#pid = system "okular #{Dir.pwd}/latgraph.eps"
			#sleep 3
			#Process.kill 'TERM', pid
			#Process.kill 'TERM', pid1
		end
	end

	
		def test_graphkit_multiplot
			unless ENV['SHORT_TEST']
			Dir.chdir('test/results') do
			
			######################
			# Make 3 random graphs
			######################
			
			
			# As usual, data can be an array or a GSL::Vector
			kit1 = GraphKit.autocreate(x: {data: [0,2,4], title: 'A label with latex \(\Gamma_\epsilon \chi\)', units: '\(\nu e\)'}, y: {data: [3.3, 5.5, 10], title: 'Label with latex \(\beta\)', units: '\(v_{thi}\)'})
			kit1.title = 'First Graph'
			kit1.gp.label = '\'A label\' at 2,7' # This 'gp' syntax is new. You can set pretty much any gnuplot option like this - see gnuplot help set
			kit1.data[0].title = 'A new title'
			
			kit2 = GraphKit.autocreate(x: {data: [0,2,4], title: 'Stuff \(\Gamma_\epsilon \chi\)', units: '\(\nu e\)'}, y: {data: [2, -1, 2], title: 'Some \(\beta\)', units: '\(v_{thi}\)'})
			kit2.title = 'Second Graph'
			kit2.data[0].gp.with = 'lp linewidth 6' # See gnuplot help plot for data options
			kit2.gp.key = 'off'
			kit2.xlabel = 'A NEW XLABEL'
			
			kit3 = GraphKit.autocreate(x: {data: [0,5,10], title: 'Mouse Height \(\Gamma_\epsilon \chi\)', units: '\(\nu e\)'}, y: {data: [4, 3, 4], title: 'Mouse weight \(\kappa\)', units: '\(v_{thi}\)'})
			kit3.title = 'Mouse info'
			kit3.data[0].gp.with = 'lp'
			kit3.gp.key = 'off'
			
			#####################
			# Plot a single one
			#####################
			
			pp kit1
			kit1.gnuplot_write('first_graph.eps', latex: true) #Just plot it by itself
			#system "okular #{Dir.pwd}/first_graph.eps"
			pp kit1
			
			###########################
			# Plot multiple graphs
			##########################

			#$debug_gnuplot=true
			kit1.gnuplot_write('aname.eps', latex: true)
			#exit
			kit2.gnuplot_write('anothername.eps', latex: true)
			kit3.gnuplot_write('athirdname.eps', latex: true, size: "2.0in,2.0in")
			
			my_preamble = <<EOF
	\\documentclass{article}
	%\documentclass[aip,reprint]{}
	\\usepackage{graphics,bm,overpic,subfigure,color}

	\\pagestyle{empty}
	\\begin{document}
	\\begin{figure}
EOF
			
			
			# Can use default preamble - just don't include preamble option in function call GraphKit.latex_multiplot('all_graphs.eps')
			GraphKit.latex_multiplot('all_graphs.eps', preamble: my_preamble) do 
	<<EOF
	\\subfigure{
	\\includegraphics{aname}
	}
	\\subfigure{
	\\begin{overpic}{anothername}
				% The location is in percent of image width
	\\put(44,22){\\includegraphics[scale=.45]
				{athirdname}}
	\\end{overpic}
	} 
EOF

			end
			#system "okular #{Dir.pwd}/all_graphs.eps"
			assert_equal("all_graphs.eps: PostScript document text conforming DSC level 2.0, type EPS\n", `file all_graphs.eps`)

			end # Dir.chdir 

			end # unless
			
			
		end # def 
	else
		puts "*******************************************************"
		puts "Warning: latex tests not being run: please specify the environment variable LATEX=true to run latex tests"
		puts "*******************************************************"
		sleep 0.1
	end # if ENV['LATEX']
		
end # class TestCodeRunner
end # if false/true

#class TestFortranNamelist < MiniTest::Test
	##require 'gs2crmod'
	#def test_make_defaults
		#Dir.chdir('test') do
			#CodeRunner.code_command('make_new_defaults_file("fortran_namelist", "fortran_namelist.in")', C: 'gs2')
			#assert(File.read('fortran_namelist_defaults.rb')=~/tprim_1/)
		#end
	#end
#end
#
#
CodeRunner::GLOBAL_OPTIONS[:non_interactive] = true
class TestFortranNamelistC < MiniTest::Test
	def setup
	end
	def test_synchronise_variables
		#FileUtils.rm('lib/cubecalccrmod/namelists.rb')
		CodeRunner.setup_run_class('cubecalc', modlet: 'with_namelist')
		assert_equal(File.read('test/cubecalc_namelist.cc').size+1, CodeRunner::Cubecalc::WithNamelist.get_aggregated_source_code_text('test').size)
		#CodeRunner::Cubecalc::WithNamelist.synchronise_variables('test')
		CodeRunner::Cubecalc::WithNamelist.synchronise_variables_from_input_file('test/cubecalc.in')
		#CodeRunner::Cubecalc::WithNamelist.update_defaults_from_source_code('test')
	end
	def test_mediawiki_write
		CodeRunner.setup_run_class('cubecalc', modlet: 'with_namelist')
		CodeRunner::Cubecalc::WithNamelist.write_mediawiki_documentation
		FileUtils.rm 'cubecalc_mediawiki.txt'
	end
	def tfolder
		'test/submit_with_namelist'
	end
	def test_submit
		CodeRunner.setup_run_class('cubecalc', modlet: 'with_namelist')
		assert_system("#$cpp_command test/cubecalc_namelist.cc -o test/cubecalc_namelist")
		CodeRunner::Cubecalc::WithNamelist.make_new_defaults_file('cubecalctest', 'test/cubecalc.in')
		FileUtils.mv('cubecalctest_defaults.rb', CodeRunner::Cubecalc::WithNamelist.rcp.user_defaults_location + '/cubecalctest_defaults.rb')
		FileUtils.makedirs(tfolder)
		CodeRunner.submit(C: 'cubecalc', m: 'with_namelist', Y: tfolder, X: Dir.pwd + '/test/cubecalc_namelist', D: 'cubecalctest', p: '{dummy_for_arrays: [0.5, 0.6], dummy_complex: [Complex(0.4,0.5), Complex(1.3, 3.4)]}')
		CodeRunner.status(Y: tfolder)
		runner = CodeRunner.fetch_runner(Y: tfolder)
		assert_equal(86.35, runner.run_list[1].volume.round(2))
		FileUtils.rm_r(tfolder)
		FileUtils.rm(CodeRunner::Cubecalc::WithNamelist.rcp.user_defaults_location + '/cubecalctest_defaults.rb')
		FileUtils.rm('test/cubecalc_namelist')
	end
end

end
