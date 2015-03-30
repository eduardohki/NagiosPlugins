#!/usr/bin/env python

##################################################################################
# check_ups_info.py
# Nagios Plugin for check Standard UPS information via SNMP with perfdata.
#
#	OID's found in: http://www.oidview.com/mibs/0/UPS-MIB.html
#
# Prerequisites:
#	net-snmp-python
#
# Release 1.2 - 2015/03/27
#	Author: Eduardo Hernacki - OpenUX <eduardo.hernacki@openux.com.br>
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

plugin_name='check_ups_info.py'
plugin_version='v1.2'

# Python modules
import sys
import optparse
import netsnmp

# Return codes definition
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Captures Plugin arguments
usage = 'Usage: ./check_ups.py -H <host> [-C <communnity>] -T <info|load|timeleft> -w <warning> -c <critical> [-h|--help]'
parser = optparse.OptionParser(usage=usage)
parser.add_option('-H', '--host', dest='host', help='Host Address', type=str)
parser.add_option('-T', '--type', dest='checkType', help='Check Type (info|load|timeleft)', type=str)
parser.add_option('-C', '--community', dest='snmpCommunity', default='public',help='SNMP Community [default: %default]', type=str)
parser.add_option('-w', '--warning', dest='warnTreshold', help='Warning treshold', type=int)
parser.add_option('-c', '--critical', dest='critTreshold', help='Critical treshold', type=int)
parser.add_option('-t', '--timeout', dest='checkTimeout', default=5, help='Check Timeout', type=int)

# Parse arguments
(options, args) = parser.parse_args()

# Host input validation
if options.host is None:
	print 'ERROR: The host must be specified!'
	print '\n%s\n' % usage
	sys.exit(CRITICAL)

# Check type input validation
if (options.checkType is None):
	print 'ERROR: Check type not found!'
	print 'Check types: info, input, output, load, timeleft'
	print '\tFor more info, run ./check_ups.py --help'
	sys.exit(CRITICAL)

# SNMP UPS-MIB definitions
upsIdentManufacturer='1.3.6.1.2.1.33.1.1.1'
upsIdentModel='1.3.6.1.2.1.33.1.1.2'
upsOutputPercentLoad='1.3.6.1.2.1.33.1.4.4.1.5'
upsEstimatedMinutesRemaining='1.3.6.1.2.1.33.1.2.3'

# SNMP collection function
def snmpOut(GetOID):
	snmpTimeout = options.checkTimeout*1000000
	session = netsnmp.Session(Version = 2, DestHost=options.host, Community=options.snmpCommunity, Timeout=snmpTimeout, Retries=0, UseNumeric=True)
	oid = netsnmp.VarList(netsnmp.Varbind('.' + GetOID))
	snmpOut = session.walk(oid)
	if session.ErrorStr:
		print 'UPS CRITICAL: %s' % session.ErrorStr
		sys.exit(CRITICAL)
	return snmpOut

# Nobreak information check
if options.checkType == 'info':
	manufacturer = '%s' % snmpOut(upsIdentManufacturer)
	model = '%s' % snmpOut(upsIdentModel)
	print 'Model: %s %s' % (manufacturer, model)
	sys.exit(OK)

# Output load check
elif  options.checkType == 'load':
	# Validates warning and critical paramameters
	if (options.warnTreshold is None) or (options.critTreshold is None) or (options.warnTreshold >= options.critTreshold):
		print 'ERROR: Please specify the Warning and Critical tresholds!'
		print '\n%s\n' % usage
		sys.exit(CRITICAL)

	# Captures SNMP output
	outputLoad = '%s' % snmpOut(upsOutputPercentLoad)

	# Threshold validation
	if str(outputLoad) >= str(options.critTreshold):
		print 'UPS CRITICAL: The output load is %s%% | OutputLoad=%s;%s;%s' % (outputLoad, outputLoad, options.warnTreshold, options.critTreshold)
		sys.exit(CRITICAL)
	elif str(outputLoad) >= str(options.warnTreshold):
		print 'UPS WARNING: The output load is %s%% | OutputLoad=%s;%s;%s' % (outputLoad, outputLoad, options.warnTreshold, options.critTreshold)
		sys.exit(WARNING)
	else:
		print 'UPS OK: The output load is %s%% | OutputLoad=%s;%s;%s' % (outputLoad, outputLoad, options.warnTreshold, options.critTreshold)
		sys.exit(OK)

# Battery timeleft check
elif  options.checkType == 'timeleft':
	# Validates warning and critical paramameters
	if (options.warnTreshold is None) or (options.critTreshold is None) or (options.warnTreshold <= options.critTreshold):
		print 'ERROR: Please specify the corectly remaining Warning and Critical minutes!'
		print '\n%s\n' % usage
		sys.exit(CRITICAL)

	# Captures SNMP output
	minutesLeft = '%s' % snmpOut(upsEstimatedMinutesRemaining)
	
	# Threshold validation
	if str(minutesLeft) <= str(options.critTreshold):
		print 'UPS CRITICAL: Battery has %s minutes remaining | TimeLeft=%s;%s;%s' % (minutesLeft, minutesLeft, options.warnTreshold, options.critTreshold)
		sys.exit(CRITICAL)
	elif str(minutesLeft) <= str(options.warnTreshold):
		print 'UPS WARNING: Battery has %s minutes remaining | TimeLeft=%s;%s;%s' % (minutesLeft, minutesLeft, options.warnTreshold, options.critTreshold)
		sys.exit(WARNING)
	else:
		print 'UPS OK: Battery has %s minutes remaining | TimeLeft=%s;%s;%s' % (minutesLeft, minutesLeft, options.warnTreshold, options.critTreshold)
		sys.exit(OK)

# Checks if the type specified exists or is null
else:
	print 'ERROR: Check type "%s" not found!' % options.checkType
	print 'Check types: info, input, output, load, timeleft'
	print '\tFor more info, run ./check_ups.py --help'
	sys.exit(CRITICAL)
