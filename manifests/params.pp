# == Class: conda::params
#
# Internal class for setting up parameters
class conda::params {
 
    $install_dir = $::kernel ? {
        'windows'     => 'C:\Anaconda',
        /(L|l)inux/   => '/opt/anaconda',
        default       => 'FAIL'
    }

    $conda_exe =  $::kernel ? {
        'windows'     => "${install_dir}\\Scripts\\conda.exe",
        /(L|l)inux/   => "${install_dir}/bin/conda",
        default       => 'FAIL'
    }

    $base_url = 'http://repo.continuum.io/miniconda'

    # Some versions of puppet report uppercase Linux
    $installer = $::kernel ? {
        /(L|l)inux/   => "Miniconda${conda::py_version}-${conda::version}-Linux-x86_64.sh",
        'windows'     => "Miniconda${conda::py_version}-${conda::version}-Windows-x86_64.exe",
        default       => 'FAIL'
    }
    $url = "${base_url}/${installer}"

    # Anaconda URLS
    $anaconda_base_url = 'http://repo.continuum.io/archive'

    $anaconda_installer = $::kernel ? {
        /(L|l)inux/ => "Anaconda${conda::py_version}-${conda::version}-Linux-x86_64.sh",
        'windows'   => "Anaconda${conda::py_version}-${conda::version}-Windows-x86_64.exe",
        default     => 'FAIL'
    }

    $anaconda_url = "${anaconda_base_url}/${anaconda_installer}"
}
