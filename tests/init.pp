class { 'conda' :
  channel => 'http://local-package-server/conda/repo',
}

conda::env { 'test_env' : }

conda::package { 'numpy' :
  env     => 'test_env',
}

