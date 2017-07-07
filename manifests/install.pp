# == Class: conda::install
#
# Internal class that does the installation work
class conda::install {
    include conda::params
    include staging::params

    if $conda::light_install {
        # Light install uses the miniconda installer
        $source    = $conda::params::url
        $installer = $conda::params::installer
    }
    else {
        # Full Anaconda install
        $source    = $conda::params::anaconda_url
        $installer = $conda::params::anaconda_installer
    }

    $installer_path = $::kernel ? {
        /(L|l)inux/   => "${staging::params::path}/conda/${installer}",
        'windows'     => "${staging::params::path}\\conda\\${installer}",
        default       => 'FAIL'
    }
    $install_dir    = $conda::params::install_dir

    $installer_exec = $::kernel ? {
        /(L|l)inux/   => "/bin/bash ${installer_path} -b -p ${install_dir}",
        'windows'     => "${installer_path} /S /D=${install_dir}",
        default       => 'FAIL'
    }

    # Only download once
    staging::file { $installer :
        source  => $source,
        timeout => $conda::download_timeout
    }

    # Only install if downloaded file changed
    exec { 'conda_install':
        command   => $installer_exec,
        creates   => $install_dir,
        subscribe => Staging::File[$installer],
	    umask 	  => $umask,
    }
}
