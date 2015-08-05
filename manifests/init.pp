############################################################
# Class: accounts
#
# Description:
#  Disable unnecessary accounts and restrict virtual
#  console logins
#
# Variables:
#  None
#
# Facts:
#  None
#
# Files:
#  None
#
# Templates:
#  None
#
# Dependencies:
#  None
############################################################
class accounts (
 $verify = true,
 $umask = '0077',
 $functionsumask = '0027',
){
  #RHEL-06-000027, RHEL-06-000028
  augeas { 'Restrict Virtual Console and Serial Port Root Logins':
    context => '/files/etc/securetty',
    lens    => 'securetty.lns',
    incl    => '/etc/securetty',
    changes => [
      'rm *[.=~regexp("vc/.*")]',
      'rm *[.=~regexp("ttyS.*")]'
    ],
  }

  #RHEL-06-000342
  exec { 'Ensure the Default Bash Umask is Set Correctly':
    command => "/bin/sed -i -r 's/(umask)([ \t]*)[0-9]+/umask $umask/gi' /etc/bashrc",
    onlyif  => "/usr/bin/test `/bin/egrep -i 'umask[[:space:]]*[0-9]+' /etc/bashrc | /bin/egrep -iv 'umask[[:space:]]*$umask' | /usr/bin/wc -l` -ne 0",
  }
  #RHEL-06-000343
  exec { 'Ensure the Default C Shell Umask is Set Correctly':
    command => "/bin/sed -i -r 's/(umask)([ \t]*)[0-9]+/umask $umask/gi' /etc/csh.cshrc",
    onlyif  => "/usr/bin/test `/bin/egrep -i 'umask[[:space:]]*[0-9]+' /etc/csh.cshrc | /bin/egrep -iv 'umask[[:space:]]*$umask' | /usr/bin/wc -l` -ne 0",
  }
  #RHEL-06-000344 
  exec { 'Replace /etc/profile umask':
    command => "/bin/sed -i -r 's/(umask)([ \t]*)[0-9]+/umask $umask/gi' /etc/profile",
    onlyif  => "/usr/bin/test `/bin/egrep -i 'umask[[:space:]]*[0-9]+' /etc/profile | /bin/egrep -iv 'umask[[:space:]]*$umask' | /usr/bin/wc -l` -ne 0",
  }
  #RHEL-06-000345 
  exec { 'Replace /etc/login.defs umask':
    command => "/bin/sed -i -r 's/(UMASK)([ \t]*)[0-9]+/UMASK $umask/gi' /etc/login.defs",
    onlyif  => "/usr/bin/test `/bin/egrep -i 'umask[[:space:]]*[0-9]+' /etc/login.defs | /bin/egrep -iv 'umask[[:space:]]*$umask' | /usr/bin/wc -l` -ne 0",
  }
  if $verify {
    # RHEL-06-000032
    exec { 'Verify Only Root Has UID 0':
      command   => "/bin/awk -F: '(\$3 == \"0\" && \$1 !=\"root\") {print}' /etc/passwd",
      user      => 'root',
      logoutput => true,
    }
    #RHEL-06-000029
    exec { 'Verify No System or Local User Accounts Have Empty Password Fields':
      command   => "/bin/awk -F: '(\$2 == \"\") {print}' /etc/shadow",
      user      => 'root',
      logoutput => true,
    }
  }

  #if using pam_oddjob_mkhomedir - we need to put the umask in the conf file
  #will break the oddjob file if somehow there was no match line
  file_line { 'Oddjob homedir umask':
    path     => '/etc/oddjobd.conf.d/oddjobd-mkhomedir.conf',
    line     => "<helper exec=\"/usr/libexec/oddjob/mkhomedir -u $umask\"",
    match    => 'exec="/usr/libexec/oddjob/mkhomedir',
    multiple => true,
    notify   => Exec[ 'Restart oddjobd' ],
  }

  #Restart oddjob only if running to pick up config change.
  exec { 'Restart oddjobd':
    command     => '/sbin/service oddjobd status; if [ $? == 0 ]; then /sbin/service oddjobd restart; fi',
    logoutput   => true,
    refreshonly => true,
  }

  # CCE-27031-4
  file_line { 'functions umask':
    path  => '/etc/init.d/functions',
    line  => "umask $functionsumask",
    match => '^umask',
  }

}
