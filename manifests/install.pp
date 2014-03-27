# == Class: conda::instal
#
# Internal class that does the installation work
class conda::install {
    include conda::params

    # Light install uses the miniconda installer
    if $conda::light_install {
        $source    = $conda::params::url
        $installer = $conda::params::installer
    }
    else {
        # Full Anaconda install
        $source    = $conda::params::anaconda_url
        $installer = $conda::params::anaconda_installer
    }

    $dl_dir         = '/tmp'
    $installer_path = "${dl_dir}/conda/${installer}"
    $install_dir    = $conda::params::install_dir

    class {'staging':
        path  => $dl_dir,
        owner => 'puppet',
        group => 'puppet',
    }

    # Only download once
    staging::file {$installer:
        source  => $source,
        timeout => $conda::download_timeout
    }

    # Only install if downloaded file changed
    exec { 'conda_install':
        command   => "/bin/bash ${installer_path} -b -p ${install_dir}",
        creates   => $install_dir,
        subscribe => Staging::File[$installer],
    }
}
