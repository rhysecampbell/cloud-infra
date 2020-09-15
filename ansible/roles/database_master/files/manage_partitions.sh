#!/bin/sh

# cloud & madis
function create_partitions {
        psql -d cloud -c "select oe.new_creation_day('$1', '$1')"
        psql -d madis -c "select oe.new_creation_day('$1', '$1')"
}
function drop_partitions {
        psql -d cloud -c "drop table oe.data_value_$1"
        psql -d madis -c "drop table oe.data_value_$1"
}

for day in -1 0 1 2 3
do
        datestring=$(date +%Y-%m-%d -d "$day day")
        create_partitions $datestring
done
for day in -5 -4 -3 -2
do
        datestring=$(date +%Y_%m_%d -d "$day day")
        drop_partitions $datestring
done


# metar
function create_partitions {
        psql -d metar -c "select oe.new_creation_week('$1', '$1');"
}
function drop_partitions {
        psql -d metar -c "drop table oe.data_value_$1"
}

for week in -1 +0 +1 +2 +3
do
        datestring=$(date +%Y-%m-%d -d "monday${week}week")
        create_partitions $datestring
done
for week in -3 -2
do
        datestring=$(date +%Y_%m_%d -d "monday${week}week")
        drop_partitions $datestring
done

touch /opt/schemas/first_partitions_created

exit 0
