test_name 'Run acceptance spec against package'
require 'pdk/pdk_helper.rb'

step 'Run the tests' do
  rspec_command = "#{command_prefix(workstation)} bundle exec rspec --pattern 'spec/acceptance/**.rb' --format json --out results.out"
  on(workstation, rspec_command, :accept_all_exit_codes => true) do |outcome|
    assert_equal(0, outcome.exit_code, 'rspec acceptance tests should exit with 0')
  end
end
