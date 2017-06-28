test_name 'Copy pdk acceptance to the System Under Test and bundle install' do
  # TODO: Need assurance that the ref of the acceptance tests is 
  # correct for the ref of the package being tested.

  #workstation = find_at_most_one('workstation')
  target_dir = create_tmpdir_on(workstation, 'pdk_acceptance')
  install_dir = workstation.platform =~ /windows/ ? "/cygdrive/c/Program\\ Files/Puppet\\ Labs/DevelopmentKit"
                                                  : '/opt/puppetlabs/sdk'
  CMD_PREFIX = "PATH=#{install_dir}/private/ruby/2.1.9/bin:#{install_dir}/private/git/bin:$PATH && cd #{target_dir} && "

  step 'Create target directory' do
    on(workstation, "mkdir -p #{target_dir}")
  end

  step 'Copy pdk acceptance tests to the System Under Test' do
    scp_to(workstation, 'spec', "#{target_dir}/spec", {recursive: true})    
  end

  step 'Copy pdk Gemfile to System Under Test' do
    scp_to(workstation, 'Gemfile', target_dir)
  end

  step 'Remove gemspec from Gemfile' do
    on(workstation, "sed -i 's/^gemspec//g' #{target_dir}/Gemfile")
  end

  step 'Install pdk gem bundle using pdk\'s ruby' do
    on(workstation, "#{CMD_PREFIX} bundle install --path vendor/bundle --without development package_testing --jobs 4 --retry 4")
  end

  step 'Check rspec is ready' do
    on(workstation, "#{CMD_PREFIX} bundle exec rspec --version") do |outcome|
      assert_match(/[0-9\.]*/, outcome.stdout, 'rspec --version outputs some version number')
    end
  end
end
