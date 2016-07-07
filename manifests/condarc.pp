define conda::condarc(
    $channels = ['http://repo.continuum.io/pkgs/pro', 'http://repo.continuum.io/pkgs/free'],
    $proxy = undef
){
    require conda
    include conda::params

    file { "${conda::params::install_dir}/.condarc":
        content => template('conda/condarc.erb'),
    } ->  Package <| provider == conda or provider == conda_pip |>
}
