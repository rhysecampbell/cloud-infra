#!/usr/bin/perl

$resultsDir = "/var/www/html/error-scripts/errorLogs";

opendir (DATES,"$resultsDir");
@dates=readdir(DATES);
close DATES;

@dates=sort(@dates);

# get rid of . and ..
shift @dates;
shift @dates;


print <<"END1";

<html>

<head>
<link rel="stylesheet" href="/error-scripts/css/style.css" type="text/css" />
<link rel="stylesheet" href="/error-scripts/css/gxt-all.css" type="text/css" />

</head>

<body>
<form method="post" action="/cgi-bin/error-cgi/errors2.cgi" target="results">

<table>
<tr>
<td style=padding:10px>
Date</br>
<select name="date">
END1

foreach $date (@dates) {
print "<option value=\"$date\">$date</option>\n";
}
print <<"END2";

</select>
</td>
</tr>
<tr>
<td style=padding:10px>
<input type="submit" value="Results">
</td>
</tr>
</table>
</form>
</body>
</html>

END2
