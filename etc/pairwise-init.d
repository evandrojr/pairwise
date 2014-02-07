#! /bin/sh
### BEGIN INIT INFO
# Provides:          pairwise
# Required-Start:    $remote_fs
# Required-Stop:     $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Example initscript
# Description:       This file should be used to construct scripts to be
#                    placed in /etc/init.d.
### END INIT INFO

# Sample init.d script for pairwise.
#
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="Pairwise web platform"
NAME=pairwise
SCRIPTNAME=/etc/init.d/$NAME

# default values
PAIRWISE_DIR=/opt/pairwise-api/
PAIRWISE_USER=pairwise

# Read configuration variable file if it is present
#[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

if [ -z "$PAIRWISE_DIR" ] || [ -z "$PAIRWISE_USER" ]; then
  echo "PAIRWISE_DIR or PAIRWISE_USER not defined, noosfero not being started."
  echo "Both variables must be defined in /etc/default/pairwise"
  exit 0
fi

#if test -x /usr/sbin/pairwise-check-dbconfig ; then
#  if ! pairwise-check-dbconfig; then
#    echo "Pairwise database access not configured, service disabled."
#    exit 0
#  fi
#fi

######################

main_script() {
  cd $PAIRWISE_DIR
  #if [ "$PAIRWISE_USER" != "$USER" ]; then
  #  su $PAIRWISE_USER -l -c "./script/production $1"
  #else
    bundle exec thin -C thin.yml $1
  #fi
}

#do_setup() {

#}

do_start() {
  #if ! running; then
    #do_setup
    # actually start the service
    main_script start
  #else
  #  echo 'Pairwise is already running, nothing to do...'
  #fi
}

do_stop() {
  #if running; then
    main_script stop
  #else
  #  echo 'Pairwise is already stopped, nothing to do...'
  #fi
}

do_restart() {
  do_stop
  do_start
}

running(){
  pgrep -f 'thin server (127.0.0.1:5030)' > /dev/null
}

case "$1" in
  start|stop|restart|setup)
    do_$1
    ;;
  force-reload)
    do_restart
    ;;
  *)
    echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload|setup}" >&2
    exit 3
    ;;
esac

