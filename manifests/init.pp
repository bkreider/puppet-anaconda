# == Class: conda
#
# Conda installs either the full install of Anaconda or the bootstrapped
# version using Miniconda.
#
# === Parameters
#
# Document parameters here.
#
# [*light_install*]
#   Defaults to true.  If set to false, a bare-bones python
#   distribution will be installed using miniconda.
#
# [*download_timeout*]
#   Defaults to 30 minutes.  The time to wait for the installer to download
#
# [*py_version*]
#   Specify Python version for the root env.  Default is Python3.
#
# [*version*]
#   Specify Anaconda version. Miniconda (light_install) supports 'latest'.  
#   Full Anaconda install requires specific version number.
#
# [*umask*]
#   Specify umask to use for the installation process of Anaconda.  
# === Examples
#
#  include conda
#
#  class { conda:
#  }
#
# === Authors
#
# Author Name bkreider@continuum.io
#
# === Copyright
#
# Copyright 2013 Continuum Analytics
#
class conda (
    $light_install    = true,
    $download_timeout = 1800,
    $channel          = undef,
    $py_version       = '3',
    $version          = '4.3.1',
    $umask	          = '0022',
) {
    include conda::install
}
