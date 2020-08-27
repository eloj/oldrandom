#!/usr/bin/perl
#
# Purpose:
#
#
# Usage:
#
#  ebookrenamer-regress [--check|--generate [infile]] [--suite <file pattern|comma-separated list>]
#
use strict;
use lib '.';
require ebookfile;
use Getopt::Long;
use Data::Dumper;

my $cfg = {
  'check' => 0,
  'generate' => '',
  'commit' => '',
  'suite' => ['regress/*.regress'],
  'verbose' => 1,
  'ask' => 1,
};

sub read_file_list
{
  my $file = shift;

  open(FILE, "<".$file) or die("Couldn't open file list '$file'");
  my @files = <FILE>;
  close(FILE);

  return \@files;
}

sub get_file_list
{
  my $dir = shift;
  opendir(DIR, $dir) or die "Uh, oh? $!";
  my @files = grep { not /^[.][.]?\z/ } readdir DIR;
  closedir DIR;
  return \@files;
}

GetOptions(
	'suite=s@{,}' => \$cfg->{'suite'},
	'check!' => \$cfg->{'check'},
	'generate=s' => \$cfg->{'generate'},
	'commit=s' => \$cfg->{'commit'},
	'verbose!' => \$cfg->{'verbose'},
	'ask!' => \$cfg->{'ask'},
);
@{$cfg->{'suite'}} = split(/,/,join(',', @{$cfg->{'suite'}}));

# Escape spaces in filenames to make globbing work more naturally
foreach (@{$cfg->{'suite'}}) { $_ =~ s/ /\\ /g; }

@{$cfg->{'suite'}} = map { glob } @{$cfg->{'suite'}};

if ($cfg->{'check'} > 0)
{ 
  my $checked = 0;
  my $regressions = 0;

  foreach my $suite (@{$cfg->{'suite'}})
  {
    print "Loading regression suite '".$suite."'\n";
    my $files = read_file_list($suite);

    while (@{$files})
    {
      my $filename = shift @{$files};
      my $regress_data = shift @{$files};
      chomp $filename;
      chomp $regress_data;

      if( $filename )
      {
        my $book = new ebookfile($filename);

        ++$checked;
        if( $book->regress_data() ne $regress_data )
        {
          print "EXPECTED: '". $regress_data."'\n";
          print "     GOT: '". $book->regress_data()."'\n";
          print "     for: '". $filename."'\n";
          ++$regressions;
        }
      }
    }
  }
  print $checked." checked, ".$regressions." regressions.\n";

  exit 0;
}

if ($cfg->{'commit'}) {
	# Parse infile

	my $aq = ();

	my $suite = '';
	my $expected = undef;
	my $got = undef;
	my $filename = undef;

	my $state = 0;
	my $packets = 0;
	# 0 = suite expected
	my $line_no = 0;
	print "Parsing regress --check output for changesets:\n" if $cfg->{'verbose'};
	open(F, "<".$cfg->{'commit'}) or die("Couldn't open file list '$cfg->{'commit'}'");
	while (my $line = <F>) {
		chomp $line;
		++$line_no;

		if ($line =~ m/^Loading regression suite '(.*?)'/) {
			$suite = $1;
			print "Populating suite '".$suite."'\n" if $cfg->{'verbose'};
			$state = 1;
		} elsif ($state == 1 || $state == 2) {
			if ($line =~ m/^EXPECTED: '(.*)'$/) {
					$expected = $1;
			} elsif ($line =~ m/\W+GOT: '(.*)'$/) {
					$got = $1;
			} elsif ($line =~ m/\W+for: '(.*)'$/) {
					$filename = $1;
			} else {
					print "IGNORING line $line_no: Unknown data '$line'.\n";
			}

			if (defined $expected && defined $got && defined $filename) {
				++$packets;
				print "Got changeset $packets.\n" if $cfg->{'verbose'};

				$aq->{$suite}->{$filename} = { 'got' => $got, 'expected' => $expected };
				$expected = undef;
				$got = undef;
				$filename = undef;
				$state = 2;
			}
		}

	}
	close(F);

	while (($suite, my $node) = each  %{$aq}) {
		my $commited_packets = 0;
		print "Committing to suite '$suite'\n";
		open(F, "<".$suite) or die("Couldn't open suite '$suite'");
		my $tempname = $suite.".new";
		open(Fnew, ">".$tempname) or die ("Couldn't open temporary suite file for writing.");
		while (1) {
			my $filename = <F>;
			last if not defined $filename;
			my $data = <F>;
			last if not defined $filename;
			chomp $filename;
			chomp $data;

			if (defined $node->{$filename}) {
					if ($node->{$filename}->{'expected'} ne $data) {
						print "ERROR: Found file '$filename' but not the expected data.\n";
					} else {
						print "Changing data for file '$filename':\n";
						print "From: '".$data."'\n  To: '".$node->{$filename}->{'got'}."'\n";
						if ($cfg->{'ask'}) {
								print " ** REALLY COMMIT THIS CHANGE? [y/n]: ";
								my $yesno = <STDIN>;
								if ($yesno =~ m/y(es)?/i) {
									$data = $node->{$filename}->{'got'};
									++$commited_packets;
								}
						} else {
							$data = $node->{$filename}->{'got'};
							++$commited_packets;
						}
					}
			}
			print Fnew $filename."\n";
			print Fnew $data."\n";
		}
		close(F);
		close(Fnew);
		print "Committing $commited_packets of ".(keys %{$node})." packets total.\n";
		rename $tempname, $suite or die ("Failed to rename file.");
	}

}

if ($cfg->{'generate'})
{
  my $files = read_file_list($cfg->{'generate'});

  foreach my $filename (@{$files})
  {
    $filename =~ s/[\n\r\l]+$//;

    if( $filename =~ m/\.(pdf|chm|ps|djvu|mobi|epub)/ )
    {
      my $book = new ebookfile($filename);

      print $filename."\n";
      print $book->regress_data()."\n";
    }
  }
  exit 0;
}

