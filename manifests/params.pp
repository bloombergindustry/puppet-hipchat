# Class: puppet_hipchat::params
#
# Parameterize for Puppet platform.
#
class puppet_hipchat::params {

  $puppetboard  = 'NONE'
  $dashboard    = 'NONE'
  $config_file  = "${::settings::confdir}/hipchat.yaml"

  if $::is_pe or str2bool($::is_pe) {
    $owner = 'pe-puppet'
    $group = 'pe-puppet'

    if $::pe_version and versioncmp($::pe_version, '3.7.0') >= 0 {
      $provider       = 'pe_puppetserver_gem'
      $master_service = 'pe-puppetserver'
    } else {
      $provider       = 'pe_gem'
      $master_service = 'pe-httpd'
    }
  } else {
    if $::puppetversion and versioncmp($::puppetversion, '4.0.0') >= 0 {
      if $::pe_server_version {
        $master_service = 'pe-puppetserver'
        $provider       = 'puppetserver_gem'
      } else {
        $master_service = 'puppetserver'
        $provider       = 'puppet_gem'
      }
    } else {
      $master_service = 'puppetmaster'
      $provider       = 'gem'
    }
    if $::pe_server_version {
      $owner = 'pe-puppet'
      $group = 'pe-puppet'
    } else {
      $owner = 'puppet'
      $group = 'puppet'
    }
  }
}
