#!/usr/bin/perl

# Script to perform several checks on rsnapshot backups

use strict;
use warnings;
use File::ReadBackwards;    # apt-get install libfile-readbackwards-perl
use Date::Parse;            # apt-get install libtimedate-perl
use Date::Language;
my $date_parse = Date::Language->new('English');


my $config_file;
if($ARGV[2])
{
    $config_file = $ARGV[2];
}
else
{
    $config_file = '/etc/rsnapshot.conf';
}
if( ! -e $config_file )
{
    print "ERROR Config $config_file not found\n";
    exit;
}

# Read the config
open(CONFIG,"<".$config_file);
my $row;
my $snapshot_root = 0;
my $logfile = 0;
while($row = <CONFIG>)
{
    if( $row =~ /^snapshot_root\s+(\S+)/ )
    {
        $snapshot_root = $1;
    }
    if( $row =~ /^logfile\s+(\S+)/ )
    {
        $logfile = $1;
    }    
}
close(CONFIG);
if(!$snapshot_root)
{
    print "ERROR No rsnapshot_root";
    exit;
}
if(!$logfile)
{
    print "ERROR No rsnapshot logfile";
    exit;
}

# Perform checks
if($ARGV[0] eq "last_successfully_backup")
{
    if(! $ARGV[1])  # Missing interval
    {
        print "ERROR Missing interval\n";
        exit;
    }
    if(! -e $logfile )
    {
        print "ERROR Cant open logfile $logfile\n";
        exit;
    }
    my $log = File::ReadBackwards->new($logfile);
    my $log_line;
    my $interval = $ARGV[1];
    while( defined( $log_line = $log->readline ) )
    {
        
        #print $log_line ;
        if( $log_line =~ /\[(.*)\].*$interval: completed successfully/ && $log_line !~ /logger/ )
        {
            print $date_parse->str2time($1);
            $log->close;
            exit;
        }
    }
    $log->close;
}
elsif($ARGV[0] eq "bytes_received")
{
    if(! $ARGV[1])  # Missing interval
    {
        print "ERROR Missing interval\n";
        exit;
    }
    if(! -e $logfile )
    {
        print "ERROR Cant open logfile $logfile\n";
        exit;
    }

    my $log = File::ReadBackwards->new($logfile);
    my $log_line;
    my $interval = $ARGV[1];
    my $do_counting = 0;
    my $bytes_received = 0;
    while( defined( $log_line = $log->readline ) )
    {
        #print $log_line ;
        if( $log_line =~ /$interval: completed successfully$/ && $log_line !~ /logger/ )
        {
            $do_counting = 1;
        }
        elsif( $log_line =~ /$interval: started$/ && $log_line !~ /logger/ )
        {
            $log->close;
            print $bytes_received;
            exit;
        }
        if( $do_counting == 1 && $log_line =~ /received ([0-9]+) bytes/ )
        {
            $bytes_received = $bytes_received+$1;
        }
    }
    $log->close;
}
elsif($ARGV[0] eq "free_backup_space")
{
    if(! -e $snapshot_root)
    {
        print "ERROR snapshot_root $snapshot_root not found";
        exit;
    }
    my $free_backup_space;
    my $df = 'df -l -P '.$snapshot_root;
    open(PIPE, $df.'|');
    while(my $row = <PIPE>)
    {
        if($row =~ /[0-9]+\s+[0-9]+\s+[0-9]+\s+([0-9]+)/)
        {
            $free_backup_space = $1;
        }
    }
    close(PIPE);
    print $free_backup_space*1024; # df gives KBytes, but we want Bytes
}
