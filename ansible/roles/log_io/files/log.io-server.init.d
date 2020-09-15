#!/bin/sh

RETVAL=0

case "$1" in
        start)  
                initctl start log.io-server
                ;;
        stop)
                initctl stop log.io-server
                ;;
        restart)
                initctl restart log.io-server || initctl start log.io-server
                ;;
        status)
                initctl status log.io-server
                pgrep log.io-server >/dev/null 2>&1
                RETVAL=$?
                ;;
        *)
                echo $"Usage: $0 {start|stop|restart|status}"
                RETVAL=1
esac    
exit $RETVAL
