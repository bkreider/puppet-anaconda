# Creates an environment with Anaconda, Python, and Numpy
# To add packages see anaconda::package

define conda::package(
  $env = undef,
  $ensure = 'present'
) {
    include conda

    if $env == undef {
        $package_name = $title
        $require      = undef
    }
    else {
        $package_name = "${env}::${title}"
        $require      = Conda::Env[$env]
    }

    package {$package_name:
        ensure   => $ensure,
        require  => $require,
        provider => conda
    }
}

