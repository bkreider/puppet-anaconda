# == Class: conda::params
#
# Internal class for setting up parameters
class conda::params {

    # Has to be hardcoded for the package provider to work
    $install_dir = '/opt/anaconda'

    # todo - remove this links
    $base_url = $::domain ? {
        'atx.continuum.io'=> 'http://filer.atx.continuum.io/released/1.6.0',
        default           => 'http://repo.continuum.io/miniconda',
    }

    # Some versions of puppet report uppercase Linux
    $installer = $::kernel ? {
        /(L|l)inux/   => 'Miniconda-1.9.1-Linux-x86_64.sh',
        'windows'     => 'Miniconda-1.6.2-Windows-x86_64.exe',
        'Darwin'      => 'Miniconda-1.6.2-MacOSX-x86_64.sh',
        default       => 'FAIL'
    }
    $url = "${base_url}/${installer}"

    # Anaconda URLS
    $anaconda_base_url = $::domain ? {
        'atx.continuum.io'=>'http://filer.atx.continuum.io/released/1.6.0',
        default           =>'http://09c8d0b2229f813c1b93-c95ac804525aac4b6dba79b00b39d1d3.r79.cf1.rackcdn.com',
    }

    $anaconda_installer = $::kernel ? {
        /(L|l)inux/ => 'Anaconda-1.9.1-Linux-x86_64.sh',
        'windows'   => 'Anaconda-1.6.2-Windows-x86_64.exe',
        'Darwin'    => 'Anaconda-1.6.1-MacOSX-x86_64.sh',
        default     => 'FAIL'
    }

    $anaconda_url = "${anaconda_base_url}/${anaconda_installer}"
}

