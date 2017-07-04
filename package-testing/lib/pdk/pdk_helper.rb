# Memoized working directory to run the tests from
def target_dir
  $target_dir ||= create_tmpdir_on(workstation, 'pdk_acceptance')
end
