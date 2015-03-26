
include conda

conda::package { 'numpy' :
  env     => 'test_env',
  channel => 'http://engbuildserver/conda/repo',
}
conda::env { 'test_env' : }

