#!/usr/bin/perl

#############################################################################
# check_lx.pl - Plugin Nagios de Administracao dos plugins OpenUX Linux.
#
# Recursos:
#       - Traz o Uptime do host [OK]
#       - Traz informações sobre o sistema (Hostname[OK], Distribuicao[OK], Plataforma[OK] e Rede[OK])
#       - Atualiza os demais plugins automaticamente
#
# Autor:  Eduardo Hernacki <eduardo.hernacki@openux.com.br>
#         OpenUX
#
# Versão 1.0 - 21/08/2014 - Versão inicial
# Versão 1.1 - 22/08/2014 - Adicionado a consulta do nome do SO no arquivo /etc/redhat-release
#                         - Removido informacao de data de instalação, inconsistente;
# Versão 1.2 - 01/09/2014 - Adicionado a consulta do nome do SO nos arquivos /etc/system-release e /etc/oracle-release
#
#
#                      GNU GENERAL PUBLIC LICENSE
#                        Version 3, 29 June 2007
#
#     Este programa é um software livre; você pode redistribui-lo e/ou
#     modifica-lo dentro dos termos da Licença Pública Geral GNU como
#     publicada pela Fundação do Software Livre (FSF); na versão 2 da
#     Licença, ou em qualquer versão.
#     Este programa é distribuido na esperança que possa ser  util,
#     mas SEM NENHUMA GARANTIA; sem uma garantia implicita de ADEQUAÇÂO
#     a qualquer MERCADO ou APLICAÇÃO EM PARTICULAR.
#     Veja a Licença Pública Geral GNU no link abaixo para maiores detalhes.
#
#     http://www.gnu.org/copyleft/gpl.txt
#
#############################################################################
#
# Define variaveis do codigo de retorno para o Nagios
$OK=0;
$WARNING=1;
$CRITICAL=2;
$UNKNOWN=3;
$plugin_name="check_lx";
$versao="v1.2";
#
# Armazena o nome do script/plugin
$plugin=__FILE__;
#
# Define os parametros do plugin
use Getopt::Long qw(:config no_ignore_case);
GetOptions(
  "h:s" => \&Help,
  );

&Uptime;
print "\n";
print &OS_Info;
print &HW_Info;
print &Net_Info;
print $PerfData;
exit $Status;

# Coleta informacoes de Hardware
sub HW_Info {
  $OSplatform=`/usr/bin/sudo /usr/sbin/dmidecode -s system-product-name`;
  $OSplatform=~s/\r?\n//g;
  $SerialNumber=`/usr/bin/sudo /usr/sbin/dmidecode -s system-serial-number`;
  $SerialNumber=~s/\r?\n//g;
  return "$OSplatform - $SerialNumber\n";
}

# Coleta a versão do SO:
sub OS_Info {
  $HostName=`/bin/hostname`;
  $HostName=~s/\r?\n//g;
  $ReleaseFile='/etc/os-release';
  $SystemFile='/etc/system-release';
  $RedHatFile='/etc/redhat-release';
  $OracleFile='/etc/oracle-release';
  $SuSEFile='/etc/SuSE-release';
  $IssueFile='/etc/issue';
  if (-e $ReleaseFile) {
    $OSversion=`/usr/bin/cat /etc/os-release | /bin/grep "PRETTY_NAME"`;
    $OSversion=~s/PRETTY_NAME\=//g;
    $OSversion=~s/\"//g;
    $OSversion=~s/\r?\n//g;
    return "$HostName - $OSversion\n";
  }
  elsif (-e $SuSEFile) {
    $OSversion=`/usr/bin/head -n 1 $SuSEFile`;
    $OSversion=~s/\r?\n//g;
    return "$HostName - $OSversion\n";
  }
  elsif (-e $SystemFile) {
    $OSversion=`/usr/bin/head -n 1 $SystemFile`;
    $OSversion=~s/\r?\n//g;
    return "$HostName - $OSversion\n";
  }
  elsif (-e $OracleFile) {
    $OSversion=`/usr/bin/head -n 1 $OracleFile`;
    $OSversion=~s/\r?\n//g;
    return "$HostName - $OSversion\n";
  }
  elsif (-e $RedHatFile) {
    $OSversion=`/usr/bin/head -n 1 $RedHatFile`;
    $OSversion=~s/\r?\n//g;
    return "$HostName - $OSversion\n";
  }
  elsif (-e $IssueFile) {
    $OSversion=`/usr/bin/head -n 1 $IssueFile`;
    $OSversion=~s/\r?\n//g;
    return "$HostName - $OSversion\n";
  }
  else {
    return "$HostName";
  }
}

# Coleta informacoes de Rede

sub Net_Info {
  $ifcfg=`LC_ALL=C /sbin/ifconfig | /bin/grep -1 'inet '`;
  $ifcfg=~s/\n//g;
  @IfDev=split(/\-\-/, $ifcfg);
  foreach $Line (@IfDev) {
    @DevInfo=split(/\ /, $Line);
    $NetDev=@DevInfo[0];
    $NetDev=~s/\://g;
    next if ($NetDev eq "lo");
    $Inet4=`LC_ALL=C /sbin/ip addr show $NetDev | /bin/grep 'inet '`;
    $Inet4=~s/inet\ //g;
    $Inet4=~s/\ /\|/g;
    $Inet4=~s/\|+/\|/g;
    $Inet4=(split /\|/, $Inet4)[1];
    $Inet6=`LC_ALL=C /sbin/ip addr show $NetDev | /bin/grep 'inet6 '`;
    $Inet6=~s/inet6\ //g;
    $Inet6=~s/\ /\|/g;
    $Inet6=~s/\|+/\|/g;
    $Inet6=(split /\|/, $Inet6)[1];
    push (@NetInfo, "Interface $NetDev > $Inet4 $Inet6\n");
  }
  return @NetInfo;
}

# Funcao de Uptime
sub Uptime {
  open FILE, "< /proc/uptime";
  ($Uptime, undef) = split / /, <FILE>;
  close FILE;
  if(defined($Uptime)) {
    $Dias = int($Uptime / 86400);
    $Segundos = $Uptime % 86400;
    $Horas = int($Segundos / 3600);
    $Segundos = $Segundos % 3600;
    $Minutos = int($Segundos / 60);
    if ($Horas == 0) {
      print "WARNING - Host reiniciado! Uptime: $Dias dia(s), $Hora(s) hora(s) e $Minutos minuto(s). $versao\n";
      $Status=$WARNING;
    }
    else {
      print "OK - Uptime: $Dias dia(s), $Horas hora(s) e $Minutos minuto(s). $versao\n";
      $Status=$OK;
    }
    $PerfData="|uptime=$Dias\n";
  }
}

# Funcao do Help
sub Help {
  print "\nPlugin Nagios para Administracao dos plugins OpenUX\n";
  print "Exibe informacoes como Hostname, Plataforma, SO e Rede\n";
  print "Atualiza os plugins OpenUX Linux automaticamente\n";
  print "\nUsage: $plugin \[-h\]\n";
  print "\nOptions:\n";
  print "          -h,   Exibe esta tela de ajuda.\n\n";
  exit $UNKNOWN;
}
