# Creates an environment with Anaconda, Python, and Numpy
# To add packages see anaconda::package or use the package provider "conda"

define conda::condarc(
    $channels = ['http://repo.continuum.io/pkgs/pro', 'http://repo.continuum.io/pkgs/free'],
    $proxy = undef
){
    require conda
    include conda::params

    file { "${conda::params::base_path}/.condarc":
        content => template('conda/condarc.erb'),
    } ->  Package <| provider == conda or provider == conda_pip |>
}
