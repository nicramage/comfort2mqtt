#! /bin/sh
# /etc/init.d/comfort2mqtt

### BEGIN INIT INFO
# Provides:          comfort2mqtt
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Cytech Comfort alarm panel and MQTT bridge.
# Description:       Translate between Cytech Comfort serial interface and MQTT.
### END INIT INFO

# If you want a command to always run, put it here
COMFORT2MQTT_DIR="$(dirname "$(realpath "$0")")"


# Carry out specific functions when asked to by the system
case "$1" in
  start)
    echo "Starting comfort2mqtt"
    # run application you want to start
    su -l -c "$COMFORT2MQTT_DIR/comfort2mqtt -d -log /var/log/comfort2mqtt/comfort2mqtt.log" pi
    ;;
  stop)
    echo "Stopping comfort2mqtt"
    while pidof comfort2mqtt >/dev/null ; do
        kill -s QUIT "$(pidof comfort2mqtt)"
        sleep 0.5
    done
    ;;
  status)
    if pidof comfort2mqtt >/dev/null;
    then
        echo "comfort2mqtt is running"
        exit 0
    else
        echo "comfort2mqtt is not running"
        exit 3
    fi
    ;;
  *)
    echo "Usage: /etc/init.d/comfort2mqtt {start|stop}"
    exit 1
    ;;
esac

exit 0

