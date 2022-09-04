#!/bin/bash

function start() {
  if [ -f /etc/rc.d/init.d/rsyslog.service ]; then
    /etc/rc.d/init.d/rsyslog.service start 
  fi
  if [ -f /etc/rc.d/init.d/isc-dhcpd.service ]; then
    /etc/rc.d/init.d/isc-dhcpd.service start
  fi
  if [ -f /etc/rc.d/init.d/glass-gui.service ]; then
    /etc/rc.d/init.d/glass-gui.service start &
  fi   
  if ! [ -f /tmp/alive ]; then stay_alive; fi
 }

function stop() {
  if [ -f /etc/rc.d/init.d/rsyslog.service ]; then
    /etc/rc.d/init.d/rsyslog.service stop 
  fi
  if [ -f /etc/rc.d/init.d/isc-dhcpd.service ]; then
    /etc/rc.d/init.d/isc-dhcpd.service stop
  fi
  if [ -f /etc/rc.d/init.d/glass-gui.service ]; then
    /etc/rc.d/init.d/glass-gui.service stop 
  fi 
 }

function stay_alive(){
 touch /tmp/alive
 exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
 
}

function restart() {
  stop
  start
}

function_exists() {
  declare -f -F $1 > /dev/null
  return $?
}

if ! [ -f /run/lock/subsys ]; then mkdir -p /run/lock/subsys; fi

if [ $# -lt 1 ]
then
  printf "Usage : $0 start|stop|restart\n"
  exit
fi

case "$1" in
  start)    function_exists start && start
          ;;
  stop)  function_exists stop && stop
          ;;
  restart)  function_exists restart && restart
          ;;  
  *)      printf "Invalid command - Valid->start|stop|restart|reload\n"
          ;;
esac