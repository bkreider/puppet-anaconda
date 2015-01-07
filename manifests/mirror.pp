# Local mirror for anaconda installers
class conda::mirror(
  $base_url = undef,
  $v2_base = undef,
  $v3_base = undef,
  $base_dir = undef,
  $mirrorscript = 'condamirror.sh',
) {
  file { $base_dir:
    ensure  => 'directory',
    mode    => '0775',
    owner   => 'root',
    group   => 'root',
  }
  file { $mirrorscript:
    ensure  => 'present',
    path    => "/usr/local/bin/${mirrorscript}",
    content => template("conda/${mirrorscript}.erb"),
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[$base_dir],
  }
  cron { 'condamirror':
    command => "/usr/local/bin/${mirrorscript}",
    user    => 'root',
    hour    => 10,
    minute  => 0,
    weekday => 6,
    require => File[$mirrorscript],
  }
}
