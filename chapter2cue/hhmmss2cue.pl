#!/usr/bin/perl -w
#
# Convert --file consisting of 'HH:MM(:SS) title' lines into cue sheet.
#
use strict;

use Getopt::Long;
use POSIX qw(strftime);

my $file = 'titles.txt';
my $verbose = 1;
my $msoffset = 0;
my $debug = 0;
my $title = '';
my $date = strftime("%Y", gmtime());
my $performer = '';
my $qt = 1;
my %d;

# Convert HH:MM:SS to MM:SS:FRAME
sub adjusttime($) {
	my $time = shift;

	my ($h,$m,$s,$ms) = split(/[:.,]/, $time);

	my $mis = ($s * 1000) + ($m*60*1000) + ($h*3600*1000) + $msoffset;

	my $om = $mis / 1000 / 60;
	my $os = ($mis / 1000) % 60;
	my $ofr = ($mis / 1000 / 60 ) % 75;
	my $res = sprintf "%02d:%02d:%02d", $om, $os, $ofr;

	return $res;
}

GetOptions(
	'file=s' => \$file,
	'title=s' => \$title,
	'performer=s' => \$performer,
	'date=s' => \$date,
	'msoffset=s' => \$msoffset,
	'quotetitles!' => \$qt,
	'verbose!' => \$verbose,
	'debug!' => \$debug
);

if (! -r $file) {
	print "Error: couldn't load file '$file'\n";
	exit(1);
}

print STDERR "WARNING: Applying offset of $msoffset ms to all track indeces.\n" if $msoffset;

open(F, "<".$file);

my $FE="\r\n";
my $QT="";

$QT = '"' if $qt;

print "FILE \"dummy.wav\" WAVE$FE";
print "TITLE \"$title\"$FE" unless $title eq '';
print "PERFORMER \"$performer\"$FE" unless $performer eq '';
print "REM DATE $date$FE" unless $date eq '';
my $lno = 0;
my $track = 1;
while(my $line = <F>) {
	++$lno;
	$line =~ s/[\r\n]+//;
	next if $line eq '';
	print STDERR "IN:'".$line."'\n" if $debug;
	if ($line =~ /(\d+:\d+:\d+)\W+([^\n\r]+)/) {
		$d{$track}->{'time'} = adjusttime($1);
		$d{$track}->{'title'} = $2;
		++$track;
	} elsif ($line =~ /(\d+:\d+)\W+([^\n\r]+)/) {
		$d{$track}->{'time'} = adjusttime("00:".$1);
		$d{$track}->{'title'} = $2;
		++$track;
	} else {
		print STDERR "WARNING: Line $lno '$line' not parsed\n" if $verbose;
	}
}

foreach my $trackno (sort {$a<=>$b} keys %d) {
	print "TRACK $trackno AUDIO$FE";
	print "  INDEX 01 ".$d{$trackno}->{'time'}."$FE";
	if (defined $d{$trackno}->{'title'} && $d{$trackno}->{'title'} ne "") {
		print "  TITLE $QT".$d{$trackno}->{'title'}."$QT$FE";
	}
}
close(F);
