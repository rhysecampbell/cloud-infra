#!/bin/sh

# forecast
function create_partitions {
        psql -d forecast -c "select oe.new_creation_day('$1', '$1')"
}
function drop_partitions {
        psql -d forecast -c "drop table oe.data_value_$1"
}

for day in -1 0 1 2 3 4 5 6 7
do
        datestring=$(date +%Y-%m-%d -d "$day day")
        create_partitions $datestring
done
for day in -5 -4 -3 -2
do
        datestring=$(date +%Y_%m_%d -d "$day day")
        drop_partitions $datestring
done

touch /opt/schemas/first_partitions_forecast_created

exit 0
