# Creates an environment with Anaconda, Python, and Numpy
# To add packages see anaconda::package or use the package provider "conda"

define conda::env( $anaconda_version=undef, $numpy='1.7', $python='2.7') {
    include conda::params

    $conda = "${conda::params::base_path}/bin/conda"

    if $anaconda_version == undef {
        $anaconda_string = 'anaconda'
    }
    else {
        $anaconda_string = "anaaconda=${anaconda_version}"
    }

    exec { "conda_env_${name}":
        command => "${conda} create --yes --quiet \
                    --name=${name} ${anaconda_string} numpy=${numpy} \
                    python=${python}",
        creates => "${conda::params::base_path}/envs/${name}",
        require => Class[conda],
        timeout => 600,

    } ->  Package <| provider == conda or provider == conda_pip |>
    # run env commands before installing packages

    # Make sure pip is installed
    package {'pip':
        ensure   => present,
        require  => Exec["conda_env_${name}"],
        provider => conda
    }
}
