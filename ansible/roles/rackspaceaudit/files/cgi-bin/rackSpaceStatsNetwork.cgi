#!/usr/bin/perl

# sample
#
# name,status,patchCount,scanCount,pubIP,serviceIP,vcsIPs
# proc1.dqm.vaicld-pre.com,1,1,2,104.130.195.205,10.210.192.211,192.168.11.5|192.168.9.4|

$resultPath='/var/www/html/securityReports';
$time=time;



open(DATA,"$resultPath/systems.csv");
@data=<DATA>;
close DATA;

print <<'HEAD';
Content-type: text/html

<!doctype html>
<html lang="en-US">
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Type" content="text/html">
  <title>VCS Systems - Security Status</title>
  <link rel="stylesheet" type="text/css" media="all" href="/securityReports/css/styles.css">
  <script type="text/javascript" src="/securityReports/js/jquery-1.10.2.min.js"></script>
  <script type="text/javascript" src="/securityReports/js/jquery.tablesorter.min.js"></script>

<style>
p.normal {
    font-style: normal;
    
}

p.italic {
    font-style: italic;
}

p.oblique {
    font-style: oblique;
}
</style>

</head>

<body>

<table background="/securityReports/images/banner-bg.png" width=100%>
<tr>
 <td width=130>
  <img src="/securityReports/images/vaisala_logo.png">
 </td>
 <td valign="middle">
  <font size=3 color=white> / VCS Systems Security Status</font>
 </td>
</tr>
</table>

<table>
<tr>
<td>
<font size=2><p class="italic"><a href="/securityReports/network/?time=$time" target="diagram">Click for full network diagram</a></p></font>
</td>
</tr>
</table>


 <div id="wrapper">
 <center><font size=3><p class="italic">Click any Column to Sort by that Column</p></font></center>
  <table id="keywords" cellspacing="0" cellpadding="0" border=1 width=100%>
    <thead>
      <tr>
        <th width=220><span>Name<br>(Click for VCS Connectivity)</span></th>
        <th><span>Status</span></th>
        <th><span>Available<br>Patches</span></th>
        <th><span>Open<br>Ports</span></th>
        <th><span>Public IP</span></th>
        <th><span>Service IP</span></th>
        <th><span>VCS IPs</span></th>
      </tr>
    </thead>
    <tbody>

HEAD
foreach $system (@data) {
	$system =~ m/([^\,]*)\,([^\,]*)\,([^\,]*)\,([^\,]*)\,([^\,]*)\,([^\,]*)\,([^\,]*)/;
		$name=		$1;
		$status=	$2;
			if ($status) {
			  $status="ON";
			  $statColor="#46a646";
			} 
			else {
			  $status="OFF";
			  $statColor="#000000";
			}
		$patchCount=	$3;
		$scanCount=	$4;
		$publicIP=	$5;
		$serviceIP=	$6;
		$vcsIPs=	$7;
		chomp $vcsIPs;

 open (PATCHES,"$resultPath/$serviceIP.patches.txt");
 @patches=<PATCHES>;
 close PATCHES;
 $patchNoteCount=@patches;
 if ($patches[0] =~ m/System Up To Date/) {
	$patchNoteCount=0;
	}


 open (SCAN,"$resultPath/$serviceIP.scan.txt");
 @scan=<SCAN>;
 close SCAN;
 $scanNoteCount= grep /open/, @scan;


if ( -e "/var/www/html/securityReports/network/systemNets/$name.png" ) {
	$linkData = "<a href=/securityReports/network/systemNets/$name.png?time=$time target=$name>$name</a>";
	}
else {
	$linkData = "$name";
}

print <<"DATA1";
      <tr>
        <td class="lalign">$linkData</td>
        <td align="middle"><font color=$statColor>$status</font></td>
DATA1


if ($patchNoteCount) {
 print "	<td align=\"middle\"><p style=\"cursor:Pointer;\" title=\"@patches\"><a href=\"/securityReports/$serviceIP.patches.txt?time=$time\" target=$serviceIP.patches>$patchNoteCount</a></p></td>\n";
  }
else {
 print "	<td align=\"middle\">0</td>\n";
  }

if ($scanNoteCount) {
 print "	<td align=\"middle\"><p style=\"cursor:Pointer;\" title=\"@scan\"><a href=\"/securityReports/$serviceIP.scan.txt?time=$time\" target=$serviceIP.scan>$scanNoteCount</a></p></td>\n";
  }
else {
 print "	<td align=\"middle\">0</td>\n";
 } 


print <<"DATA2";
        <td>$publicIP</td>
        <td>$serviceIP</td>
        <td>$vcsIPs</td>
      </tr>
DATA2
}

print <<'END';
    </tbody>
  </table>
 </div>
<script type="text/javascript">
$(function(){
  $('#keywords').tablesorter(); 
});
</script>
</body>
</html>
END
