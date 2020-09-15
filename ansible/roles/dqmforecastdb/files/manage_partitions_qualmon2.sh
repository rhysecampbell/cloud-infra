#!/bin/sh

# metar
function create_partitions {
        psql -d qualmon2 -c "select qm.data_creation_week('$1', '$1');"
        psql -d qualmon2 -c "select qm.quality_creation_week('$1', '$1');"
}
function drop_partitions {
        psql -d qualmon2 -c "truncate table qm.data_quality_$1"
        psql -d qualmon2 -c "drop table qm.data_quality_$1"
        psql -d qualmon2 -c "truncate table qm.data_value_$1"
        psql -d qualmon2 -c "drop table qm.data_value_$1"
}

for week in -2 -1 +0
do
        datestring=$(date +%Y-%m-%d -d "monday${week}week")
        create_partitions $datestring
done
for week in -4 -3
do
        datestring=$(date +%Y_%m_%d -d "monday${week}week")
        drop_partitions $datestring
done

touch /opt/schemas/first_partitions_qualmon2_created

exit 0
