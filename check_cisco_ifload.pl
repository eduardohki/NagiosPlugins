#!/usr/bin/perl

################################################################################
# check_cisco_ifload.pl
# Nagios Plugin for check Cisco Device Port Bandwidth (RX/TX)
#
# Prerequisites:
#	net-snmp-utils
#
# Release 1.0 - 2015/05/27
#	Author: Eduardo Hernacki <eduardohki@gmail.com>
#
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
################################################################################

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

# Script Usage
$usage="Usage: $plugin_name -H <host> [-C <communnity>] -if <port_ID> -w <MB/s> -c <MB/s> [ -l | --list-interfaces ] [-h | --help]\n";

use Getopt::Long qw(:config no_ignore_case);
GetOptions(
	"H:s" => \$host,
	"C:s" => \$community,
	"if:s" => \$interface,
	"w:i" => \$warning,
	"c:i" => \$critical,
	"l|list-interfaces:s" => \&listInterfaces,
	"h|help:s" => \&help,
	);

# OLD-CISCO-INTERFACES-MIB Definition
$IfInBitsSec = '1.3.6.1.4.1.9.2.2.1.1.6';
$IfOutBitsSec = '1.3.6.1.4.1.9.2.2.1.1.6';

# Help sub
sub help {
	print "\n$plugin_name $plugin_version - Nagios Plugin for check Cisco Device Port Bandwidth (RX/TX)\n\n";
	print $usage;
	print "\nSyntax:\n";
	print "    -H : Host address\n";
	print "    -C : SNMP Community (Default: \"public\")\n";
	print "    -if : Port ID to check bandwidth\n";
	print "    -w : Warning treshold (in MB/s)\n";
	print "    -c : Critical treshold (in MB/s)\n";
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

# Warning and Critical Treshold Validation
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

# Get interface Info
$inLoad = &getSNMP("$IfInBitsSec.$interface");
$outLoad = &getSNMP("$IfOutBitsSec.$interface");

# Convert from bit/sec to Mbytes/sec
$inLoad = ($inLoad / 1000 / 1000) * 0.125;
$outLoad = ($outLoad / 1000 / 1000) * 0.125;

# Round Float point
$inLoad = sprintf("%.2f", $inLoad);
$outLoad = sprintf("%.2f", $outLoad);

if ($inLoad >= $critical || $outLoad >= $critical) {
	print "CRITICAL: In: $inLoad MB/s, Out: $outLoad MB/s|rx=$inLoad\;tx=$outLoad\;\n";
	exit $CRITICAL;
} elsif ($inLoad >= $warning || $outLoad >= $warning) {
	print "WARNING: In: $inLoad MB/s, Out: $outLoad MB/s|rx=$inLoad\;tx=$outLoad\;\n";
	exit $WARNING;
} else {
	print "OK: In: $inLoad MB/s, Out: $outLoad MB/s|rx=$inLoad\;tx=$outLoad\;\n";
	exit $OK;
}

# If anything goes wrong
exit $UNKNOWN;
