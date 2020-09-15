#!/bin/bash

export path="/home/triton"

for range in 0 100 200 300 400 500 600 700 800 900 1000 1100 1200
do
    $path/scripts/tritonAPI-Obs-multi.pl $range &
done

# Wait for pl to complete
for job in `jobs -p`
do
    echo "waiting for $job"
    wait $job || true
done

# Run sendcc if it isn't already
if ! pgrep -f "sendcc -c triton.con"
then
    /usr/local/bin/sendcc -c triton.conf &
fi
