#!/usr/bin/perl
#
# Purpose:
#   strip crap from and fix up ebook filenames
#
# Usage:
#
#  ebookrenamer --file "pattern" --nodry-run
#
# History:
#   2007-12-23  eloj  First version
#
# To-do:
#   do a collect pass, and warn if any two or more files map to the same name (req. user resolution)
#
require ebookfile;
use Getopt::Long;
use Data::Dumper;
use strict;

my $dir = ".";
my $action = $ARGV[0];
my $renamed = 0;

my $cfg = {
  'dry-run' => 1,
  'file' => ['*.pdf', '*.chm'],
  'verbose' => 1,
#  'ask' => 0,
};

if (scalar @ARGV < 1) {
	print "$0 usage: --file \"pattern\" --[no]dry-run --[no]verbose\n";
	exit 0;
}

GetOptions(
	'file=s@' => \$cfg->{'file'},
	'dry-run!' => \$cfg->{'dry-run'},
	'verbose!' => \$cfg->{'verbose'},
#	'ask!' => \$cfg->{'ask'},
);


# Escape spaces in filenames to make globbing work more naturally
foreach (@{$cfg->{'file'}}) { $_ =~ s/ /\\ /g; }

foreach my $filename (map { glob $_ } (@{$cfg->{'file'}}))
{
  if( $filename =~ m/\.(pdf|chm|djvu)/ )
  {
    my $book = new ebookfile($filename);

    my $newfn = $book->publisher()." - ".$book->title().($book->edition() ? " (".$book->edition()." ed)" : "").".".$book->ext();

    print $filename." => ";
    if( $filename ne $newfn )
    {
      print "\n".$newfn."\n";
      if( $book->warnings() )
      {
        print "Warnings: ".join(", ", $book->warnings() ).". -- FILE NOT RENAMED!\n";
      } else {
        die "Oops! A file called '$newfn' already exists!\n" if -e $newfn;
		++$renamed;
        if( !$cfg->{'dry-run'} ) { rename($filename, $newfn); }
      }
    } else {
      print "<UNCHANGED>\n";
    }
  }
}

if ($cfg->{'dry-run'}) {
	print "DRY-RUN: No files actually renamed. Run with --nodry-run to actualize changes.\n" if $cfg->{'verbose'};
}

print $renamed." file(s) renamed.\n" if $cfg->{'verbose'};

