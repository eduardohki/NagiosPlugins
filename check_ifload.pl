#!/usr/bin/perl

##################################################################################
# check_ifload.pl
# Nagios Plugin to check any Network Device Port Bandwidth (RX/TX)
#
# Prerequisites:
#	net-snmp-utils
#
# Release 1.0 - 2015/12/04
#	Author: Eduardo Hernacki <eduardohki@gmail.com>
#
#
#		      GNU GENERAL PUBLIC LICENSE
#		       Version 3, 29 June 2007
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
########################################################################################

# Plugin Information
$plugin_name = $0;
$plugin_version = "v1.0";

# Nagios return codes
$OK = 0;
$WARNING = 1;
$CRITICAL = 2;
$UNKNOWN = 3;

# Plugin parameters
$community = "public";	# Default community
$pollingTime = 5;	# Default polling time
$mbMulti = 1048576; # Multiplier used in octet conversion
$mode = 1;	# Don't alert if Link is down
$minSpeed = 0.005;	# Default minimal bandwidth to check if link is down

# Script Usage
$usage="Usage: $plugin_name -H <host> [-C <communnity>] -if <port_ID> -w <Mbps> -c <Mbps> [ -l | --list-interfaces ] [ -m | --mode <1,2> ] [ -s <0.xxx> ] [-h | --help]\n";

use Getopt::Long qw(:config no_ignore_case);
GetOptions(
	"H:s" => \$host,
	"C:s" => \$community,
	"if:s" => \$interface,
	"w:i" => \$warning,
	"c:i" => \$critical,
	"p:s" => \$pollingTime,
	"m|mode:i" => \$mode,
	"s:f" => \$minSpeed,
	"l|list-interfaces:s" => \&listInterfaces,
	"h|help:s" => \&help
	);

# Interface Octets OID's
$ifInOctets = '1.3.6.1.2.1.2.2.1.10';
$ifOutOctets = '1.3.6.1.2.1.2.2.1.16';

# Help sub
sub help {
	print "\n$plugin_name $plugin_version - Nagios Plugin to check any Network Device Port Bandwidth (RX/TX)\n\n";
	print $usage;
	print "\nSyntax:\n";
	print "    -H : Host address\n";
	print "    -C : SNMP Community (Default: \"public\")\n";
	print "    -if : Port ID to check bandwidth\n";
	print "    -w : Warning treshold (in Mbit/s)\n";
	print "    -c : Critical treshold (in Mbit/s)\n";
	print "    -p : Polling Time in seconds\n";
	print "    -m | --mode : Specify if the plugin should alert if link is down\n";
	print "        Options:\n";
	print "            1 : don't check if interface is down\n";
	print "            2 : alert if interface or link is down\n";
	print "    -s : Specify the minimal speed (in Mbps, ex: 0.005) to alert when \"mode\" option is set to 2 (0.005 is default)\n";
	print "    -l | --list-interfaces : List all interfaces available in the Device\n";
	print "    -h | --help : Show this help screen\n\n";
	exit $UNKNOWN;
}

sub getSNMP() {
	if (! $host) {
		print "ERROR: You must specify the host address!\n";
		print $usage;
		exit $CRITICAL;
	}
	$OID = $_[0];
	$snmpwalk = `/usr/bin/snmpwalk -v2c -c $community -Oqv $host $OID 2>&1`;
	if ($? == -1) {
		print "CRITICAL: $!\n";
		exit $CRITICAL;
	}
	if ($? != 0) {
		print "CRITICAL: Error in SNMP Command! (verify SNMP community?)\n";
		print $snmpwalk;
		exit $CRITICAL;
	}
	chomp($snmpwalk);
	return $snmpwalk;
}

sub listInterfaces {
	$ports = &getSNMP("ifIndex");
	@portID=split(/\n/, $ports);
	print "Port ID\tInterface\tDescription\t\tStatus\tBandwidth\n";
	foreach $i (@portID) {
		$portName = &getSNMP("ifName.$i");
		if (length($portName) < 8) {
			$portName.="\t";
		}
		$portAlias = &getSNMP("ifAlias.$i");
		if (!$portAlias) {
			$portAlias = "none\t";
		}
		if (length($portAlias) < 16) {
			$portAlias.="\t";
		}
		$portStatus = &getSNMP("ifOperStatus.$i");
		$portSpeed = &getSNMP("ifSpeed.$i");
		$portSpeed = ($portSpeed / 1000) / 1000;
		if (!$portSpeed) {
			$portSpeed = "N/A";
		} elsif ($portSpeed % 1000 == 0) {
			$portSpeed = $portSpeed / 1000;
			$portSpeed .= " Gbit/s";
		} else {
			$portSpeed .= " Mbit/s";
		}
		print "$i\t$portName\t$portAlias\t$portStatus\t$portSpeed\n";
	}
	exit $UNKNOWN;
}

# Script Argument Validation
if (! $host) {
	print "ERROR: You must specify the host address!\n";
	print $usage;
	exit $CRITICAL;
}
if (! $interface) {
	print "ERROR: You must specify the interface!\n";
	print "You can list available interfaces using \"-l\" option\n";
	exit $CRITICAL;
}

# Warning and Critical treshold Validation
if ($warning || $critical) {
	if ($warning && $critical) {
		if ($warning >= $critical) {
			print "ERROR: Warning cannot be higher than Critical!\n";
			print $usage;
			exit $CRITICAL;
		}
	} else {
		print "ERROR: You must specify Warning and Critical tresholds!\n";
		print $usage;
		exit $CRITICAL;
	}
} else {
	print "ERROR: You must specify Warning and Critical tresholds!\n";
	print $usage;
	exit $CRITICAL;
}

# Get interface label
$ifLabel = &getSNMP("ifAlias.$interface");
chomp($ifLabel);
# ajusts interface alias
if ($ifLabel) {
	$ifLabel = " ($ifLabel)";
}

# Get initial octet info from the interface
$inOctetsInit = &getSNMP("$ifInOctets.$interface");
$outOctetsInit = &getSNMP("$ifOutOctets.$interface");

# sleep $pollingTime seconds
sleep $pollingTime;

# Get final octet info from the interface
$inOctetsFinal = &getSNMP("$ifInOctets.$interface");
$outOctetsFinal = &getSNMP("$ifOutOctets.$interface");

# checks if the interface is Down
if ($inOctetsInit == $inOctetsFinal && $outOctetsInit == $outOctetsFinal && $mode == 2) {
	print "CRITICAL:$ifLabel Interface is Down!|rx=0Mbps\;$warning\;$critical tx=0Mbps\;$warning\;$critical\n";
	exit $CRITICAL;
}

# Calcutlates if speed
# Input
$inOctetsDiff = ( $inOctetsFinal - $inOctetsInit ) * 8;
$inLoad = ( $inOctetsDiff / $pollingTime ) / $mbMulti;
# Output
$outOctetsDiff = ( $outOctetsFinal - $outOctetsInit ) * 8;
$outLoad = ( $outOctetsDiff / $pollingTime ) / $mbMulti;

# round the float number
$inLoad = sprintf("%.3f", $inLoad);
$outLoad = sprintf("%.3f", $outLoad);

# verify if bandwidth is too low, matching link down
if ($mode == 2 && $inLoad <= $minSpeed && $outLoad <= $minSpeed) {
	print "CRITICAL:$ifLabel Link is Down!|rx=${inLoad}Mbps\;$warning\;$critical tx=${outLoad}Mbps\;$warning\;$critical\n";
	exit $CRITICAL;
}

# verify bandwidth tresholds
if ($inLoad >= $critical || $outLoad >= $critical) {
	print "CRITICAL:$ifLabel ${inLoad}Mbps in, ${outLoad}Mbps out|rx=${inLoad}Mbps\;$warning\;$critical tx=${outLoad}Mbps\;$warning\;$critical\n";
	exit $CRITICAL;
} elsif ($inLoad >= $warning || $outLoad >= $warning) {
	print "WARNING:$ifLabel ${inLoad}Mbps in, ${outLoad}Mbps out|rx=${inLoad}Mbps\;$warning\;$critical tx=${outLoad}Mbps\;$warning\;$critical\n";
	exit $WARNING;
} else {
	print "OK:$ifLabel ${inLoad}Mbps in, ${outLoad}Mbps out|rx=${inLoad}Mbps\;$warning\;$critical tx=${outLoad}Mbps\;$warning\;$critical\n";
	exit $OK;
}

exit $UNKNOWN;

