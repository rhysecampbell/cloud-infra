#!/usr/bin/perl

require("cgi-lib.pl");
&ReadParse(*input);

$resultsDir = "/var/www/html/error-scripts/results";

$date=  $input{'date'};

unless ($date =~ m/^\d{8}/) {
	print "Content-type: text/html\n\n";
	exit;
	}

opendir (RESULTS,"$resultsDir/$date/");
@results=readdir(RESULTS);
closedir RESULTS;

@results=sort(@results);

# get rid of . and ..
shift @results;
shift @results;

print <<"END1";
Content-type: text/html

<html>
<head>
<title>Error Counts</title>


<link rel="stylesheet" href="/error-scripts/css/style.css" type="text/css" />
<link rel="stylesheet" href="/error-scripts/css/gxt-all.css" type="text/css" />


    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
      google.setOnLoadCallback(drawChart);
      function drawChart() {
        var data = google.visualization.arrayToDataTable([
          ['Sensor', '# of Errors'],
END1

foreach $sensor (@results) {
	chomp $sensor;
        if ( -d "$resultsDir/$date/$sensor") {
                opendir (SENSOR,"$resultsDir/$date/$sensor");
                while (readdir SENSOR) { ++$totals; }
                closedir SENSOR;
                if ($totals) {$totals=$totals-2;}       # get rid of the . and ..
                }
        else {
                $totals=0;
                }
        $errorCount{$sensor}=$totals;
        $totals=0;
        }


foreach $value (sort by_value keys %errorCount){
        print "[\'$value\', $errorCount{$value}],\n";
        }
        sub by_value { $errorCount{$b} <=> $errorCount{$a}; }


print <<"END2";

        ]);

        var options = {
          title: 'Sensor',
          backgroundColor: '#ECECEC',
          fontSize: 14,
          chartArea: { left: 90, top: 50 },
        };

        var chart = new google.visualization.BarChart(document.getElementById('chart_div'));
        chart.draw(data, options);
      }
    </script>





</head>


<center><font size=5>$date</font></center>

    <div id="chart_div" style="height: 6000px;"></div>

  </body>
</html>
END2
