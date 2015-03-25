
package { 'test_env::pip' :
  ensure          => 'latest',
  source          => 'http://conda.rep.os/',
  provider        => 'conda',
}

