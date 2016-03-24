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
    $version          = '2.5.0',
) {
    include conda::install
}
