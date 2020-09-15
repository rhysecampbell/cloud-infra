#!/bin/sh

if [ -z "$9" ] || ! [ -z "${10}" ]
then
  echo Usage: $0 COUNTRY LAYER WIDTH HEIGHT TOP BOTTOM LEFT RIGHT TRANSPARENCY
  exit 1
fi

COUNTRY=$1
LAYER=$2

WIDTH=$3
HEIGHT=$4

TOP=$5
BOTTOM=$6
LEFT=$7
RIGHT=$8

TRANSPARENCY=$9

INPUT=/var/local/radar/working/$COUNTRY
OUTPUT=/var/www/html/radar/$COUNTRY
ANIMATED=$INPUT/animated
RESOURCES=/var/local/radar/resources/$COUNTRY

PRIVATEKEY="pgyw84lkjf8k"
CID="bgeoqg7"

TIMESTRING=$(date +%Y%m%d%H%M00)
DATESTRING=$(date +%Y%m%d)

CODE=$(echo ${DATESTRING}${PRIVATEKEY} | md5sum)
CODE=${CODE:0:32}

#sleep $[( $RANDOM % 60 ) +1 ]s

/usr/local/bin/fetch_foreca_radar.py $COUNTRY $LAYER $WIDTH $HEIGHT $TOP $BOTTOM $LEFT $RIGHT

for image in $INPUT/*.png
do
	if ! [ -e "$image" ]
	then
		break
	fi
	echo "processing $image"

	filename=$(basename $image)
	date="20${filename:0:2}-${filename:2:2}-${filename:4:2} ${filename:6:2}:${filename:8:2} UTC"

	while pgrep convert
	do
	    sleep 5
	done

	convert \
                -respect-parentheses \
                \( -size 1x1 xc:"rgb(0,255,255)" xc:"rgb(0,0,192)" xc:"rgb(0,192,0)" xc:"rgb(255,255,0)" xc:"rgb(255,128,0)" xc:"rgb(128,0,0)" xc:"rgb(128,0,128)" xc:"rgb($TRANSPARENCY)" +append +write mpr:gma_colourtable \) \
                \( $image -remap mpr:gma_colourtable +write mpr:OUT1 \) \
                \( mpr:OUT1 -fuzz 0% -transparent 'rgb('"$TRANSPARENCY"')' -write mpr:OUT2 \) \
                \( mpr:OUT2 -fuzz 0% -fill 'rgb(0,167,171)' -opaque 'rgb(0,255,255)' +write mpr:OUT1 \) \
                \( mpr:OUT1 -fuzz 0% -fill 'rgb(0,130,96)' -opaque 'rgb(0,0,192)' +write mpr:OUT2 \) \
                \( mpr:OUT2 -fuzz 0% -fill 'rgb(0,150,55)' -opaque 'rgb(0,192,0)' +write mpr:OUT1 \) \
                \( mpr:OUT1 -fuzz 0% -fill 'rgb(0,232,10)' -opaque 'rgb(255,255,0)' +write mpr:OUT2 \) \
                \( mpr:OUT2 -fuzz 0% -fill 'rgb(39,255,36)' -opaque 'rgb(255,128,0)' +write mpr:OUT1 \) \
                \( mpr:OUT1 -fuzz 0% -fill 'rgb(255,230,0)' -opaque 'rgb(128,0,0)' +write mpr:OUT2 \) \
                \( mpr:OUT2 -fuzz 0% -fill 'rgb(255,152,0)' -opaque 'rgb(128,0,128)' +write $image \) \
                null:

	echo "putting animated version into $ANIMATED/$filename"
	convert $image -resize ${WIDTH}x${HEIGHT}\! -pointsize 12 -fill white -undercolor maroon -gravity NorthWest -annotate +5+5 "$date" $ANIMATED/$filename

done

while pgrep convert
do
    sleep 5
done
convert -dispose previous -delay 1 -loop 0 $ANIMATED/*.png $ANIMATED/output.gif
convert $RESOURCES/background.png $ANIMATED/output.gif -loop 0 $OUTPUT/temp.gif

mv $OUTPUT/temp.gif $OUTPUT/loop.gif
mv $INPUT/*.png $OUTPUT/

find $ANIMATED -maxdepth 1 -type f -mmin +360 -name \*.png -delete
find $OUTPUT -maxdepth 1 -type f -mmin +360 -name \*.png -delete
