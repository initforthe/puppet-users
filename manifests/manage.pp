# Manages an user, his home and files
define users::manage (
  Struct[{
    authorized_keys => Optional[
      Tuple[String, default]
    ],
    groups         => Optional[
      Array[String, 1]
    ],
    managehome     => Boolean,
    home           => Optional[String],
    managepassword => Boolean,
    password       => Optional[String[0, default]],
    present        => Boolean,
    ssh            => Optional[
      Struct[{
        key       => String[1, default],
        key_label => String[1, default],
        key_type  => String[7, 7],
      }]
    ],
  }] $userdata
) {
  File {
    group => $name,
    mode  => '0700',
    owner => $name,
  }

  if $userdata['home'] {
    $home = $userdata['home']
  } else {
    $home = "/home/${name}"
  }

  $ensure_user = $userdata['present'] ? {
    false => absent,
    true  => present,
  }

  $user_password = $userdata['managepassword'] ? {
    true  => empty($userdata['password']) ? {
      false => $userdata['password'],
      true  => '',
    },
    false => undef,
  }

  user { $name:
    ensure   => $ensure_user,
    password => $user_password,
    shell    => '/bin/bash',
    groups   => empty($userdata['groups']) ? {
      false => $userdata['groups'],
      true  => [],
    },
    home     => $home,
    require  => Package[[keys($::users::mandatory_dependencies)], [keys($::users::extra_dependencies)]],
  }

  if $userdata['present'] and $userdata['managehome'] {

      file { $home:
        ensure  => directory,
        mode    => '0755',
        owner   => $name,
        require => User[$name],
      }

      file { "${home}/.ssh":
        ensure  => directory,
        owner   => $name,
        require => File[$home],
      }

      # Manage SSH keys
      $ssh_public_key = try_get_value($userdata, 'ssh/key')
      $ssh_private_key = try_get_value($::users::secrets, "${name}/ssh/private_key")

      if !empty($ssh_public_key) {
        File{ "${name}_ssh_public_key":
          content => $ssh_public_key,
          group   => $name,
          mode    => '0655',
          owner   => $name,
          path    => "${home}/.ssh/${name}.pub",
        }
      }

      if !empty($ssh_private_key) {
        File{ "${name}_ssh_private_key":
          content => $ssh_private_key,
          group   => $name,
          mode    => '0600',
          owner   => $name,
          path    => "${home}/.ssh/${name}"
        }
      }

      # Manage authorized_keys
      if ! empty($userdata['authorized_keys']) {
        file { "/home/${name}/.ssh/authorized_keys":
          ensure  => present,
          content => epp('users/authorized_keys', {'authorized_users' => $userdata['authorized_keys']}),
          owner   => $name,
          require => File["${home}/.ssh"],
        }
      }
    }

  else {

    file { $home:
      ensure  => absent,
      force   => true,
      require => User[$name],
    }

  }

}
