# Creates an environment with Anaconda, Python, and Numpy
# To add packages see anaconda::package

# todo: change base_path
define conda::package($env=undef, $ensure='present') {
    include conda
    include conda::params

    $conda = "${conda::params::base_path}/bin/conda"

    if $env == undef {
        $package_name = "${env}::${title}"
        $require      = undef
        }
    else {
        $package_name = $title
        $require      = Conda::env[$env]
    }

    package {$package_name:
        ensure   => $ensure,
        require  => $require,
        provider => conda
    }
}
