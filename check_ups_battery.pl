#!/usr/bin/perl

##################################################################################
# check_ups_battery.pl 
# Nagios Plugin for check Generic UPS Battery Load, with remaining time left info
#
# Prerequisites:
#	net-snmp-utils
#
# Release 1.0 - 2014/12/18
#	Author: Eduardo Hernacki - OpenUX <eduardo.hernacki@openux.com.br>
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

use Getopt::Long qw(:config no_ignore_case);
GetOptions(
	"H:s" => \$host,
	"C:s" => \$community,
	"w:i" => \$warn,
	"c:i" => \$crit,
	"h|help:s" => \&help,
	);
# OID Definition
$OIDBatteryCharge='1.3.6.1.2.1.33.1.2.4';
$OIDBatteryTimeLeft='1.3.6.1.2.1.33.1.2.3';

# Script Usage
$usage="Usage: $plugin_name -H <host> [-C <communnity>] -w <waning_\%_left> -c <critical_\%_left> [-h | --help]\n";

# Help sub
sub help {
	print "\n$plugin_name $plugin_version - Nagios Plugin for check Generic UPS Battery Load, with remaining time left info\n\n";
	print $usage;
	print "\nSyntax:\n";
	print "    -H Host address\n";
	print "    -C SNMP Community (Default: \"public\" )\n";
	print "    -w  Warning % Left\n";
	print "    -c  Critical % Left\n";
	print "    -h | --help    Show the help screen\n\n";
	exit $UNKNOWN;
}

# Script Argument Validation
if ( ! $host ) {
	print "ERROR: You must specify the UPS Address!\n";
	print $usage;
	exit $CRITICAL;
}

if ( $warn || $crit ) {
	if ( $warn && $crit ) {
		if ( $warn <= $crit ) {
			print "ERROR: Warning cannot be lower than Critical!\n";
			print $usage;
			exit $CRITICAL;
		}
	}
	else {
		print "ERROR: You must specify Warning and Critical tresholds!\n";
		print $usage;
		exit $CRITICAL;
	}
}

# SNMP check sub
sub getInfo() {
	$OID = $_[0];
	$snmpwalk = `/usr/bin/snmpwalk -v2c -c $community -Oqvt $host $OID 2>&1`;
	if ($? == -1) {
		print "CRITICAL: $!\n";
		exit $CRITICAL;
	}
	if ($? != 0) {
		print "CRITICAL: Error in SNMP Command!\n";
		print $snmpwalk;
		exit $CRITICAL;
	}
	chomp($snmpwalk);
	return $snmpwalk;
}

# Capture and formats the SNMP Output
$BatteryPercent = &getInfo($OIDBatteryCharge);
$BatteryTimeLeft = &getInfo($OIDBatteryTimeLeft);

# Check parameters
if ( $BatteryPercent <= $crit ) {
	print "UPS CRITICAL: Battery Charge is $BatteryPercent\%! ($BatteryTimeLeft minutes)|'Battery Charge'=$BatteryPercent\;$warn\;$crit\;\n";
	exit $CRITICAL;
}
elsif ( $BatteryPercent <= $warn ) {
	print "UPS WARNING: Battery Charge is $BatteryPercent\%! ($BatteryTimeLeft minutes)|'Battery Charge'=$BatteryPercent\;$warn\;$crit\;\n";
	exit $CRITICAL;
}
else {
	print "UPS OK: Battery Charge is $BatteryPercent\% ($BatteryTimeLeft minutes)|'Battery Charge'=$BatteryPercent\;$warn\;$crit\;\n";
	exit $OK;
}
