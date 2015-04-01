class { 'conda' :
  channel => 'http://engbuildserver/conda/repo',
}

conda::env { 'test_env' : }

conda::package { 'numpy' :
  env     => 'test_env',
}

