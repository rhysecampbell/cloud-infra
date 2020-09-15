#!/bin/sh

RETVAL=0

case "$1" in
        start)  
                initctl start pg-py-webservice
                ;;
        stop)
                initctl stop pg-py-webservice
                ;;
        restart)
                initctl restart pg-py-webservice || initctl start pg-py-webservice
                ;;
        status)
                initctl status pg-py-webservice
                pgrep pg-py-webservice >/dev/null 2>&1
                RETVAL=$?
                ;;
        *)
                echo $"Usage: $0 {start|stop|restart|status}"
                RETVAL=1
esac    
exit $RETVAL
