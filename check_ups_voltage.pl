#!/usr/bin/perl

##################################################################################
# check_ups_voltage.pl 
# Nagios Plugin for check Generic UPS Input and Output Voltage, by range
#
# Prerequisites:
#	net-snmp-utils
#
# Release 1.0 - 2014/12/18
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
	"T:s" => \$checktype,
	"min:i" => \$rangeMin,
	"max:i" => \$rangeMax,
	"h|help:s" => \&help,
	);
# OID Definition
$OIDInputVoltage='1.3.6.1.2.1.33.1.3.3.1.3';
$OIDOutputVoltage='1.3.6.1.2.1.33.1.4.4.1.2';

# Script Usage
$usage="Usage: $plugin_name -H <host> [-C <communnity>] -T <check_type> --min <volts> --max <volts> [-h | --help]\n";

# Help sub
sub help {
	print "\n$plugin_name $plugin_version - Nagios Plugin for check Generic UPS Input and Output Voltage, by range\n\n";
	print $usage;
	print "\nSyntax:\n";
	print "    -H Host address\n";
	print "    -C SNMP Community (Default: \"public\" )\n";
	print "    -T Check Type:\n";
	print "		input: Input Voltage (in volts)\n";
	print "			--min   Min input voltage (in volts)\n";
	print "			--max   Max input voltage (in volts)\n";
	print "		output: Output Voltage (in volts)\n";
	print "			--min   Min output voltage (in volts)\n";
	print "			--max   Max output voltage (in volts)\n";
	print "    -h | --help    Show the help screen\n\n";
	exit $UNKNOWN;
}

# Script Argument Validation
if ( ! $host ) {
	print "ERROR: You must specify the UPS Address!\n";
	print $usage;
	exit $CRITICAL;
}
if ( ! $checktype ) {
	print "ERROR: You must specify the check type!\n";
	print "Check types available: \"input\", \"output\"\n";
	exit $CRITICAL;
}

if ( ! $rangeMin || ! $rangeMax ) {
	print "ERROR: You must specify Min and Max Voltage tresholds!\n";
	print $usage;
	exit $CRITICAL;
}
elsif ( $rangeMin && $rangeMax ) {
	if ( $rangeMin >= $rangeMax ) {
		print "ERROR: Min Voltage cannot be higher than Max Voltage!\n";
		print $usage;
		exit $CRITICAL;
	}
}

# SNMP check sub
sub getInfo() {
	$OID = $_[0];
	$snmpwalk = `/usr/bin/snmpwalk -v1 -c $community -Oqv $host $OID 2>&1`;
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

# Input Voltage check
if ( $checktype eq "input") {

	# Capture and formats the SNMP Output
	$InVolts = &getInfo($OIDInputVoltage);
	if ( $InVolts < $rangeMin || $InVolts > $rangeMax ) {
		print "UPS CRITICAL: Input Voltage is $InVolts Volts!|'Input Voltage'=$InVolts\;$rangeMin\;$rangeMax\;\n";
		exit $CRITICAL;
		}
	else {
		print "UPS OK: Input voltage is $InVolts Volts|'Input Voltage'=$InVolts\;$rangeMin\;$rangeMax\;\n";
		print @description;
		exit $OK;
	}
}

# Output Voltage check
elsif ( $checktype eq "output") {

	# Capture and formats the SNMP Output
	$OutVolts = &getInfo($OIDOutputVoltage);
	if ( $OutVolts < $rangeMin || $OutVolts > $rangeMax ) {
		print "UPS CRITICAL: Output Voltage is $OutVolts Volts!|'Output Voltage'=$OutVolts\;$rangeMin\;$rangeMax\;\n";
		exit $CRITICAL;
		}
	else {
		print "UPS OK: Output voltage is $OutVolts Volts|'Output Voltage'=$OutVolts\;$rangeMin\;$rangeMax\;\n";
		print @description;
		exit $OK;
	}
}

else {
	print "ERROR: Check Type \"$checktype\" not found!\n";
	print "Check types available: \"input\", \"output\"\n";
	exit $CRITICAL;
}
