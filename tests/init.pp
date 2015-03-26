
include conda

conda::package { 'numpy' :
  env => 'test_env',
}
conda::env { 'test_env' : }

