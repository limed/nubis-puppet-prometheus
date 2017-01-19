# Class: nubis_prometheus
# ===========================
#
# Full description of class nubis_prometheus here.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `sample variable`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'nubis_prometheus':
#      servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# Authors
# -------
#
# Author Name <author@domain.com>
#
# Copyright
# ---------
#
# Copyright 2017 Your name here, unless otherwise noted.
#
class nubis_prometheus($version = '1.4.1', $blackbox_version = '0.3.0', $tag_name='monitoring', $project=undef) {
  if (!$project) {
    $project = $::project_name
  }

  $prometheus_url = "https://github.com/prometheus/prometheus/releases/download/v${version}/prometheus-${version}.linux-amd64.tar.gz"
  $blackbox_url = "https://github.com/prometheus/blackbox_exporter/releases/download/v${blackbox_version}/blackbox_exporter-${blackbox_version}.linux-amd64.tar.gz"

file { '/opt/prometheus':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}

file { '/etc/prometheus':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}->
file { '/etc/prometheus/rules.d':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}
file { '/etc/prometheus/nubis.rules.d':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}
file { '/var/lib/prometheus':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}

notice ("Grabbing prometheus ${version}")
staging::file { "prometheus.${version}.tar.gz":
  source => $prometheus_url,
}->
staging::extract { "prometheus.${version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/prometheus',
  require => File['/opt/prometheus'],
}

notice ("Grabbing blackbox ${blackbox_version}")
staging::file { "blackbox.${blackbox_version}.tar.gz":
  source => $blackbox_url,
}->
staging::extract { "blackbox.${blackbox_version}.tar.gz":
  strip   => 1,
  target  => '/usr/local/bin',
  creates => '/usr/local/bin/blackbox_exporter',
}

include 'upstart'

upstart::job { 'blackbox':
    description    => 'Prometheus Blackbox Exporter',
    service_ensure => 'stopped',
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    env            => {
      'SLEEP_TIME' => 1,
      'GOMAXPROCS' => 2,
    },
    user           => 'root',
    group          => 'root',
    script         => '
  if [ -r /etc/profile.d/proxy.sh ]; then
    echo "Loading Proxy settings"
    . /etc/profile.d/proxy.sh
  fi

  exec /usr/local/bin/blackbox_exporter -config.file /etc/prometheus/blackbox.yml -log.level info -log.format "logger:syslog?appname=blackbox_exporter&local=7"
',
    post_stop      => '
goal=$(initctl status $UPSTART_JOB | awk \'{print $2}\' | cut -d \'/\' -f 1)
if [ $goal != "stop" ]; then
    echo "Backoff for $SLEEP_TIME seconds"
    sleep $SLEEP_TIME
    NEW_SLEEP_TIME=`expr 2 \* $SLEEP_TIME`
    if [ $NEW_SLEEP_TIME -ge 60 ]; then
        NEW_SLEEP_TIME=60
    fi
    initctl set-env SLEEP_TIME=$NEW_SLEEP_TIME
fi
',
}

}
