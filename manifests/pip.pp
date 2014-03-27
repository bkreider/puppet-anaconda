# Creates an environment with Anaconda, Python, and Numpy
# To add packages see anaconda::package

define conda::pip($ensure='present', $env=undef) {
    include conda::params

    $conda = "${conda::params::base_path}/bin/conda"

    if $env == undef {
        $path_real = "${conda::params::base_path}/bin"
        $require   = undef
    }
    else {
        $path_real = "${conda::params::base_path}/envs/${env}"
        $require   = Conda::env[$env]
    }

    # Requiring the env is overkill, since it is handled by conda::env
    # but it makes the dependency more explicit - ie: the env must first exist
    package{ $title:
        ensure   => $ensure,
        provider => conda_pip,
        require  => $require,
    }
}
