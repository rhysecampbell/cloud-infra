#!/bin/sh

RETVAL=0

case "$1" in
        start)  
                initctl start uwsgi
                ;;
        stop)
                initctl stop uwsgi
                ;;
        restart)
                initctl restart uwsgi || initctl start uwsgi
                ;;
        status)
                initctl status uwsgi
                pgrep uwsgi >/dev/null 2>&1
                RETVAL=$?
                ;;
        *)
                echo $"Usage: $0 {start|stop|restart|status}"
                RETVAL=1
esac    
exit $RETVAL
