# Memoized working directory to run the tests from
def target_dir
  $target_dir ||= create_tmpdir_on(workstation, 'pdk_acceptance')
end

def install_dir(host)
  host.platform =~ /windows/ ? "/cygdrive/c/Program\\ Files/Puppet\\ Labs/DevelopmentKit"
                             : '/opt/puppetlabs/sdk'
end

def command_prefix(host)
  "PATH=#{install_dir(host)}/private/ruby/2.1.9/bin:#{install_dir(host)}/private/git/bin:$PATH && cd #{target_dir} && "end
