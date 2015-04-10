# Creates an environment with Anaconda
# To add packages see anaconda::package or use the package provider "conda"

define conda::env (
    $env_name = $title,
    $python = '2.7',
) {
    require conda
    include conda::params

    $conda = $conda::params::conda_exe
    $channel = $conda::channel

    if $channel == undef {
        $command = "${conda} create --yes --quiet -n ${env_name} python=${python}"
    } else {
        $command = "${conda} create --yes --quiet --channel ${channel} --override-channels -n ${env_name} python=${python}"
    }

    exec { "conda_env_${env_name}":
        command => $command,
        creates => "${conda::params::install_dir}/envs/${env_name}",
        require => Class[conda],
        timeout => 600,

    } ->  Package <| provider == conda or provider == conda_pip |>
    # run env commands before installing packages

    # Make sure pip is installed
    package { 'pip' :
        ensure   => present,
        require  => Exec["conda_env_${env_name}"],
        provider => conda,
        source   => $channel,
    }
}
