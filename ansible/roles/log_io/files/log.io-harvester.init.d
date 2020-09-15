#!/bin/sh

RETVAL=0

case "$1" in
        start)  
                initctl start log.io-harvester
                ;;
        stop)
                initctl stop log.io-harvester
                ;;
        restart)
                initctl restart log.io-harvester || initctl start log.io-harvester
                ;;
        status)
                initctl status log.io-harvester
                pgrep log.io-harvester >/dev/null 2>&1
                RETVAL=$?
                ;;
        *)
                echo $"Usage: $0 {start|stop|restart|status}"
                RETVAL=1
esac    
exit $RETVAL
