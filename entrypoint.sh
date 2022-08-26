#!/bin/bash

function start() {
  ServerList="rsyslog isc-dhcpd glass-gui"
  for server in ${ServerList}; do
    if [ -f /etc/rc.d/init.d/${server}.service ]; then
      /etc/rc.d/init.d/${server}.service start 
    fi
  done
  if [[ "$(pgrep -f 'sleep infinity'>/dev/null;echo $?)" -eq "1" ]];then  
    stay_alive
  fi
 }

function stop() {
  ServerList="glass-gui isc-dhcpd rsyslog"
  for server in ${ServerList}; do
    if [ -f /etc/rc.d/init.d/${server}.service ]; then
      /etc/rc.d/init.d/${server}.service stop 
    fi
  done

function stay_alive(){
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
  *)      printf "Invalid command - Valid->start|stop|restart\n"
          ;;
esac