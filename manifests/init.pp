# Class: puppet_hipchat
#
# Send Puppet report information to HipChat
#
class puppet_hipchat (
  $api_key                    = undef,
  $room                       = undef,
  $from                       = 'Puppet',
  $enabled                    = true,
  $notify_color               = 'red',
  $notify_room                = false,
  $statuses                   = ['changed','failed'],
  $config_file                = $puppet_hipchat::params::config_file,
  $provider                   = $puppet_hipchat::params::provider,
  $master_service             = $puppet_hipchat::params::master_service,
  $owner                      = $puppet_hipchat::params::owner,
  $group                      = $puppet_hipchat::params::group,
  $puppetboard                = $puppet_hipchat::params::puppetboard,
  $dashboard                  = $puppet_hipchat::params::dashboard,
  $exclude                    = ['NONE'],
  $hipchat_max_message_length = 5000,
) inherits puppet_hipchat::params {

  if $enabled {
    file { $config_file:
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => '0440',
      content => template("${module_name}/hipchat.yaml.erb"),
    }

    package { 'httparty':
      ensure   => '~> 0.14.0',
      provider => $provider,
    }

    package { 'hipchat':
      ensure   => '~> 1.5.0',
      provider => $provider,
      require  => Package['httparty'],
    }
  }

  Ini_subsetting {
    path                 => $::settings::config,
    section              => 'master',
    setting              => 'reports',
    subsetting_separator => ',',
    subsetting           => 'hipchat',
    value                => '',
  }
  if $enabled {
    ini_subsetting { 'puppet_hipchat report': ensure => present, }
  } else {
    ini_subsetting { 'puppet_hipchat report': ensure => absent, }
  }

  Service <| title == $master_service |> {
    subscribe +> Class[$title],
  }
}
