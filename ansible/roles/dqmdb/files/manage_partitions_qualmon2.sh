#!/bin/sh

# metar
function create_partitions {
        psql -d qualmon2 -c "select qm.data_creation_week('$1', '$1');"
        psql -d qualmon2 -c "select qm.quality_creation_week('$1', '$1');"
}

archive=$(psql qualmon2 -c "select spcname from pg_tablespace where spcname='archive_current';" | grep archive_current)

if [ $archive == "archive_current" ]; then
    psql -d qualmon2 "drop extension pg_repack;"
    psql -d qualmon2 "create extension pg_repack;"
    function drop_partitions {
            for tablename in data_quality_$1 data_value_$1
            do
                if ! psql -t --no-align -d qualmon2 -c "select tablename from pg_tables where tablespace='archive_current' and schemaname='qm';" | grep $tablename
                then
                    /usr/pgsql-9.3/bin/pg_repack --tablespace=archive_current --moveidx --table=qm.$tablename qualmon2
                fi
            done
    }
    dropweeks="-4 -3 -2"
else
    function drop_partitions {
	    psql -d qualmon2 -c "truncate table qm.data_quality_$1"
	    psql -d qualmon2 -c "drop table qm.data_quality_$1"
	    psql -d qualmon2 -c "truncate table qm.data_value_$1"
	    psql -d qualmon2 -c "drop table qm.data_value_$1"
    }
    dropweeks="-4 -3"
fi

for week in -2 -1 +0
do
        datestring=$(date +%Y_%m_%d -d "monday${week}week")
        create_partitions $datestring
done
for week in $dropweeks
do
        datestring=$(date +%Y_%m_%d -d "monday${week}week")
        drop_partitions $datestring
done

touch /opt/schemas/first_partitions_qualmon2_created

exit 0
