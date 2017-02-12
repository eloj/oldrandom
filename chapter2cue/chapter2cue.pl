#!/usr/bin/perl -w
use strict;

use Getopt::Long;

my $file = 'chapter.txt';
my $verbose = 1;
my $msoffset = 0;
my $debug = 0;
my $title = '';
my $performer = '';
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
	'msoffset=s' => \$msoffset,
	'verbose!' => \$verbose,
	'debug!' => \$debug
);

if (! -r $file) {
	print "Error: couldn't load infile '$file'\n";
	exit(1);
}

print STDERR "WARNING: Applying offset of $msoffset ms to all track indeces.\n" if $msoffset;

open(F, "<".$file);

my $FE="\r\n";

print "FILE \"dummy.wav\" WAVE$FE";
print "TITLE \"$title\"$FE" unless $title eq '';
print "PERFORMER \"$performer\"$FE" unless $performer eq '';
my $lno = 0;

while(my $line = <F>) {
	++$lno;
	$line =~ s/[\r\n]+//;
	next if $line eq '';
	print STDERR "IN:'".$line."'\n" if $debug;
	if ($line =~ /^CHAPTER(\d+)=(\d+:\d+:\d+\.\d+)/) {
		$d{$1}->{'time'} = adjusttime($2);
	} elsif ($line =~ /^CHAPTER(\d+)NAME=([^\n\r]+)/) {
		$d{$1}->{'title'} = $2;
	} else {
		print STDERR "WARNING: Line $lno '$line' not parsed\n" if $verbose;
	}
}

foreach my $trackno (sort keys %d) {
	print "TRACK $trackno AUDIO$FE";
	print "  INDEX 01 ".$d{$trackno}->{'time'}."$FE";
	print "  TITLE \"".$d{$trackno}->{'title'}."\"$FE" if defined $d{$trackno}->{'title'};

}
close(F);


