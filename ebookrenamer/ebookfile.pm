#
# ebookfile package
# (C)2007, 2008 Eddy L O Jansson <eddy@klopper.net>
#
# Example:
#   my $book = new ebookfile($filename);
#   my $newfn = $book->publisher()." - ".$book->title().($book->edition() ? " (".$book->edition()." ed)" : "").".".$book->ext();
#
#
package ebookfile;
use strict;
use ebookisbn;

#
# Note: Use the non-capturing grouping operator (?:pattern) here:
# Note: ^ is implicit
#
my %publishers = (
  "Peachpit Press" => { RE => [ qr/peachpit.press/i ] },
  "MIT Press" => { RE => [ qr/(?:the.)?mit.press/i ] },
  "CRC Press" => { RE => [ qr/crc(.press)?/i ] },
  "O'Reilly" => { RE => [ qr/o.?reilly/i ] },
  "APress" => { RE => [ qr/apress/i ] },
  "Cambridge University Press" => { RE => [ qr/cambridge(?:.university?)?(?:.press)?/i ] },
  "Focal Press" => { RE => [ qr/focal.press/i ] },
  "IGI Global" => { RE => [ qr/igi.(global|publishing)/i ] },
  "McGraw-Hill" => { RE => [ qr/mc[\. ]?graw(?:.hill)?/i ] },
  "Auerbach" => { RE => [ qr/auerbach(?:.publications)?/i ] },
  "Butterworth-Heinemann" => { RE => [ qr/butterworth(?:.heinemann)?/i, qr/B\.H.publishing/i ] },
  "Morgan Kaufmann" => { RE => [ qr/morgan.kaufmann(?:.publishers)?/i ] },
  "Pragmatic Programmers" => { RE => [ qr/pragmatic(?:.programmers)?/i ] },
  "Que" => { RE => [ qr/que/i ] },
  "SAS Publishing" => { RE => [ qr/sas(.publishing)?/i ] },
  "SitePoint" => { RE => [ qr/sitepoint/i ] },
  "Springer" => { RE => [ qr/springer(?:.verlag)?/i ] },
  "Syngress" => { RE => [ qr/syngress/i ] },
  "Wiley" => { RE => [ qr/((?:john.)?will?ey(?:.and.sons)?(?:.(inc\b|interscience))?|for.dummies)/i ] },
  "Wordware" => { RE => [ qr/wordware/i ] },
  "Wrox" => { RE => [ qr/wrox/i ] },
  "Digital Press" => { RE => [ qr/digital.press/i ] },
  "Newnes" => { RE => [ qr/newnes/i ] },
  "Sams" => { RE => [ qr/sams/i ] },
  "Scientific American" => { RE => [ qr/scientific.american/i ], FLAGS => { 'KEEP_DATE' => 1 } },
  "Dr.Dobb's" => { RE => [ qr/dr.dobb.?s/i ] },
  "Sybex" => { RE => [ qr/sybex/i ] },
  "Addison Wesley" => { RE => [ qr/addison.wesley/i ] },
  "Packt" => { RE => [ qr/packt(?:.publishing)?/i ] },
  "Cisco Press" => { RE => [ qr/cisco.press/i ] },
  "FriendsOfED" => { RE => [ qr/(friends.?of.?ed|FoED)/i ] },
  "No Starch Press" => { RE => [ qr/no.starch(?:.press)?/i ] },
  "Manning" => { RE => [ qr/manning/i ] },
  "IBM Press" => { RE => [ qr/ibm.press/i ] },
  "MS Press" => { RE => [ qr/(microsoft|ms).press/i ] },
  "IOS Press" => { RE => [ qr/ios.press/i ] },
  "Prentice Hall" => { RE => [ qr/prentice(?:.hall)?/i ] },
  "New Riders" => { RE => [ qr/new.riders(?:.press)?/i ] },
  "Mongoose Publishing" => { RE => [ qr/(DnD|mongoose(?:.publishing)?)/i ] },
  "Adobe Press" => { RE => [ qr/adobe.press/i ] },
  "UniCAD" => { RE => [ qr/unicad(?:.publishing)?/i ] },
  "IRM Press" => { RE => [ qr/irm.press/i ] },
  "Maximum Press" => { RE => [ qr/maximum.press/i ] },
  "Academic Press" => { RE => [ qr/academic.press/i ] },
  "Orchard" => { RE => [ qr/orchard(?:.publications)?/i ] },
  "CyberTech" => { RE => [ qr/cybertech(?:.publishing)?/i ] },
  "Elsevier" => { RE => [ qr/elsevier/i ] },
  "Routledge" => { RE => [ qr/routledge/i ] },
  "Chapman & Hall" => { RE => [ qr/chapman/i ] },
  "Frommer's" => { RE => [ qr/frommer'?s?/i ] }, # , FLAGS => { 'KEEP_DATE' => 1 } },
  "Brill" => { RE => [ qr/brill/i ] },
  "Palgrave" => { RE => [ qr/palgrave/i ] },
  "Rowman & Littlefield Publishers" => { RE => [ qr/Rowman/i ] },
  "Oxford University Press" => { RE => [ qr/oxford(?:.university)?(?:.press)?/i ] },
  "IEEE" => { RE => [ qr/IEEE/i ] },
  "ISR" => { RE => [ qr/([Ii]nformation.[Ss]cience.[Rr]eference|ISR|IDEA)/ ] },
  "Open University Press" => { RE => [ qr/(open.university.press|OUP)/i ] },
  "Idea Group" => { RE => [ qr/idea.group(?:.publishing)?/i ] },
  "Amacom" => { RE => [ qr/amacom/i ] },
  "ASCD" => { RE => [ qr/ASCD/i ] },
  "EDP" => { RE => [ qr/EDP/i ] },
  "Birkhauser" => { RE => [ qr/Birkhauser/i ] },
  "HarperCollins" => { RE => [ qr/(harper.?collins|harper|collins)/i ] },
  "Edinburgh University Press" => { RE => [ qr/(edinburgh(?:.university)?(?:.press)?|EUP)/i ] },
  "Praeger" => { RE => [ qr/praeger/i ] },
  "Gabler" => { RE => [ qr/gabler/i ] }, # Springer
  "Intellect" => { RE => [ qr/intellect/i ] },
  "University of Minnesota Press" => { RE => [ qr/UOMP/i ] },
  "University of California Press" => { RE => [ qr/UOCP/i ] },
  "State University of New York" => { RE => [ qr/SUNY/i ] },
  "Nova Science Publishers" => { RE => [ qr/NSP/i ] },
  "Prologika Press" => { RE => [ qr/prologika(?:.press)?/i ] },
  "SkillSoft" => { RE => [ qr/skillsoft(?:.corporation)?/i ] },
  "Informa" => { RE => [ qr/informa/i ] },
  "Lexington" => { RE => [ qr/lexington/i ] },
  "Sage" => { RE => [ qr/sage/i ] },
  "Pluto Press" => { RE => [ qr/pluto(?:.press)?/i ] },
  "Blackwell" => { RE => [ qr/(bmj|blackwell)/i ] },
  "Morgan & Claypool" => { RE => [ qr/morgan.claypool/i ] },
  "Ashgate" => { RE => [ qr/ashgate/i ] },
  "Temple University Press" => { RE => [ qr/temple(?:.univ?(ersity)?(?:.press)?)?/i ] },
  "Georgetown University Press" => { RE => [ qr/(georgetown(?:.university?)?(?:.press)?|gup)/i ] },
  "New York University Press" => { RE => [ qr/(new york(?:.university?)?(?:.press)?|nyup)/i ] },
  "Princeton University Press" => { RE => [ qr/(princeton(?:.university?)?(?:.press)?|pup)/i ] },
  "York University Press" => { RE => [ qr/(york(?:.university?)?(?:.press)?|yup)/i ] },
  "Taylor & Francis" => { RE => [ qr/taylor[. ](&|and)?[. ]?francis?/i ] },
  "Pearson" => { RE => [ qr/pearson/i ] },
  "Architectural Press" => { RE => [ qr/architectural.press/i ] },
  "University of Texas Press" => { RE => [ qr/(university.of.texas(?:.press)?|uotp)/i ] },
  "Britannica" => { RE => [ qr/britannica/i ] },
  "Chelsea House" => { RE => [ qr/chelsea.house/i] },
  "Infobase" => { RE => [ qr/infobase(.publishing)?/i ] },
  "Kogan Page" => { RE => [ qr/kogan.page/i ] },
  "Amsterdam University Press" => { RE => [ qr/(amsterdam(?:.university?)?(?:.press)?|aup)/i ] },
  "Indiana University Press" => { RE => [ qr/(indiana(?:.university?)?(?:.press)?|iup)/i ] },
  "Vieweg" => { RE => [ qr/vieweg/i ] },
  "Cengage Learning" => { RE => [ qr/(cengage(?:.learning))/i ] },
  "Penguin" => { RE => [ qr/penguin/i ] },
  "Thomson Gale" => { RE => [ qr/thomson.gale/i ] },
  "Thomson" => { RE => [ qr/thomson/i ] },
  "Tidbits" => { RE => [ qr/tidbits/i ] },
  "Little Brown and Company" => { RE => [ qr/little.brown.and.company/i ] },
  "Doubleday" => { RE => [ qr/doubleday/i ] },
  "LearningExpress" => { RE => [ qr/learning.express/i ] },
  "Kennel Club Books" => { RE => [ qr/kennel.club.books/i ] },
  "Hodder Education" => { RE => [ qr/hodder(?:.education)?/i ] },
  "Artech" => { RE => [ qr/artech(?:.house)?/i ] },
  "Allen & Unwin" => { RE => [ qr/allen[. ](&|and)?[. ]?unwin/i ] },
  "Allworth Press" => { RE => [ qr/allworth(?:.press)?/i ] },
  "Course Technology PTR" => { RE => [ qr/course.technology(?:.ptr)?/i ] },
  "Charles River Media" => { RE => [ qr/charles.river.media/i ] },
  "DK Publishing" => { RE => [ qr/(DK|Dorling.Kindersley)(?:.publishing)?/i ] },
  "ISTE" => { RE => [ qr/ISTE/ ] },
  "Basic Books" => { RE => [ qr/basic.books/i ] },
  # "" => { RE => [ qr//i ] },
);


# Substitutions against the raw filename as passed in.
my %globals_pre = (
  0 => { 'subst' => "",			RE => qr/^LMi/ },
  1 => { 'subst' => "",			RE => qr/-?(?:reallyusefulebooks|DDU)/i },
  2 => { 'subst' => ".",		RE => qr/(retail.|[. ])eBook(-.*?\.|\.)/i },
  3 => { 'subst' => " dot NET",		RE => qr/\.NET/ },
  4 => { 'subst' => "AJAX",		RE => qr/ajax/i },
  5 => { 'subst' => "dot",		RE => qr/dot dot/ },  # bit of hackery to remove 'dot dot' due to the "ASP.NET" vs "dot.NET" issue.
  6 => { 'subst' => "2nd.ed",		RE => qr/second.ed(ition)?/i },
  7 => { 'subst' => "",			RE => qr/[(]?(Elements.)?ATTiCA(.Elements)?[)]?/i },
  8 => { 'subst' => "",			RE => qr/[(]Elements[)]/i },
);

# Substitutions against the final title.
my %globals_post = (
  "VMware" => qr/vmware/i ,
  "C++" => qr/C plus plus/i ,
  "C-Sharp" => qr/(\bc sharp\b|C#)/i ,
  "F-Sharp" => qr/\bf sharp\b/i ,
  "" => qr/From Novice To Professional/i ,
  " IDE " => qr/ ide /i ,
  " ESX " => qr/ esx /i ,
  " for " => qr/ for /i ,
  " and " => qr/ and /i ,
#  " using " => qr/ using /i ,
  " in " => qr/ in /i ,
  "to the" => qr/\bTo The\b/ ,
  "Book, Period" => qr/\bBook Period\b/ ,
  "Celko's" => qr/\bCelkos\b/i ,
  "Beginner's Guide" => qr/\bBeginners Guide\b/i ,
  "A Beginner's" => qr/\bA Beginners\b/i ,
  "A Designer's" => qr/\bA Designers\b/i ,
  "A Programmer's" => qr/\bA Programmers\b/i ,
#  "Administrator's" => qr/\bAdministrators\b/i ,
  # Remove " with DVD$" ?!
);

my %months = (
 1 => [ 'jan', 'january' ],
 2 => [ 'feb', 'february' ],
 3 => [ 'mar' ],
 4 => [ 'apr', 'april' ],
 5 => [ 'may' ],
 6 => [ 'jun', 'june' ],
 7 => [ 'jul', 'july' ],
 8 => [ 'aug', 'august'],
 9 => [ 'sep', 'september' ],
 10 => [ 'oct', 'october' ],
 11 => [ 'nov', 'november' ],
 12 => [ 'dec', 'december' ]
);


sub new {
    my $classname = shift;
    my $self = {};
    bless($self, $classname);
    $self->_init(@_);            # Call _init with remaining args
    $self->parse();
    return $self;
}

sub _init {
    my $self = shift;

    $self->{FILENAME} = shift;
    $self->{FILENAME} =~ s/[\n\r\l]+$//;

    $self->{WARNINGS} = ();
    $self->{EXT} = undef;
    $self->{PUBLISHER} = undef;
    $self->{YEAR} = undef;
    $self->{TITLE} = undef;
    $self->{ISBN} = undef;
    #if (@_) {
    #    my %extra = @_;
    #    @$self{keys %extra} = values %extra;
    #}
}

sub filename {
    my $self = shift;
    return $self->{FILENAME};
}

sub parse {
    my $self = shift;
    my $l = 0;
    my $fn = $self->{FILENAME};

    # Remove repeated whitespace
    #$fn =~ s/\s+/ /g;

    # Pre-Globals
	#print "PRE'$fn'\n";
    while( (my $key,my $data) = each(%globals_pre) )
    {
      $fn =~ s/$data->{'RE'}/$data->{'subst'}/g;
	#	print "XXX'$fn'\n";
    }

    # Remove extension
    if( ($l = rindex($fn, ".")) > -1 )
    {
      $self->{EXT} = substr($fn, $l+1);
      $fn = substr($fn, 0, $l);
    } else {
      push(@{$self->{WARNINGS}}, "File suffix not identified");
    }

    # Remove noise from the beginning of the filename
    $fn =~ s/^[ -.]+//;

    # to-do: Locate any ISBN and set the field, and then remove it and any
    # [ ] or ( ) it's enclosed in....
    $self->{ISBN} = ebookisbn::find_and_remove_isbn($fn);

    # Remove noise from the beginning of the filename
    $fn =~ s/^[ -.]+//;

	my $flags = ();
	my $breakout = 0;
    #print "WORKING on ".$fn."\n";
    # For all publishers, try to find a pattern that matches.
	
	keys %publishers; # use keys in scalar context to reset iterator for 'each'
    OUTER: while( (my $pub, my $pub_node) = each(%publishers) ) {
      #print "Processing ".$pub.": ";
      foreach my $pattern (@{$pub_node->{RE}})
      {
        #print " ... trying pattern '".$pattern."'\n";
        if( $fn =~ m/^($pattern)/ )
        {
          #print "**MATCHED**";
          $self->{PUBLISHER} = $pub;
		  $flags = $pub_node->{FLAGS};
		  
          $fn = substr($fn, length($1)); # Remove publisher from string
          last OUTER;
        }
      }
    }

    # No publisher found, make a best guess.
    # This would probably be a bit better off by using stopwords and lengths too.
    if( ! defined $self->{PUBLISHER})
    {
	  $fn =~ m/[().,]/;
      my $punc_loc = $-[0] || -1;
	  $l = index($fn, " - ", 0);  
      if (($l > -1) && ($punc_loc == -1 || $punc_loc > $l)) {
        $self->{PUBLISHER} = substr($fn, 0, $l);
        $fn = substr($fn, $l); # Remove publisher from string
        push(@{$self->{WARNINGS}}, "Publisher guessed");
	  } elsif( ($l = index($fn, ".", 0)) > -1 ) {
        $self->{PUBLISHER} = substr($fn, 0, $l);
        $fn = substr($fn, $l); # Remove publisher from string
        push(@{$self->{WARNINGS}}, "Publisher guessed");
      } else {
        push(@{$self->{WARNINGS}}, "Publisher NOT found");
      }
    }

    # Eat whitespace and dots in front and back.
    $fn =~ s/^[\s.-]*//g;
    $fn =~ s/[\s.]*$//;

    # Remove proper or other tags.
    # to-do: Should be part of pre-processing cleanup?
    $fn =~ s/\Wproper$//i;

    # Eat whitespace and dots at the back
    $fn =~ s/[\s.]*$//;

	# Find current YYYY-MM or MM-YYYY in parenthesis
	my $year_no_keep = 0;
	if( $fn =~ /(\(20[0-9]{2}(-[01][0-9])?\))$/ || $fn =~ /(\([01][0-9]-20[0-9]{2}\))$/ )
#	if( $fn =~ /(\(([01][9]-)?[12][0-9]{3}(-[01][9])?\))$/ )
	{
		my $ym = $1;
		my $org_ym = $ym;
		$year_no_keep = 1; # In parenthesis, so we'll not be reinsering in title later.
		$ym =~ s/[()]//g;
		my ($a,$b) = split(/-/, $ym);
		if ($a > 1900) {
				$self->{YEAR} = $a;
				$self->{MONTH} = $b;
				$fn =~ s/\Q$org_ym\E//;
		} elsif ($b > 1900) {
				$self->{YEAR} = $b;
				$self->{MONTH} = $a;
				$fn =~ s/\Q$org_ym\E//;
		}
	}

    # Find the year, if any
    if( $fn =~ /([12][0-9][0-9][0-9])$/ )
    {
      $self->{YEAR} = $1;
      $fn = substr($fn, 0, length($fn)-length($1)) unless defined $flags->{KEEP_DATE};
    }

    # Eat whitespace and dots at the back
    $fn =~ s/[\s.]*$//;

    # Find out month (+year)
    while( ((my $mon, my $list) = each(%months)) )
    {
      foreach my $month (@{$list})
      {
        if( $fn =~ /($month)$/i )
        {
          $self->{MONTH} = $1;
          $fn = substr($fn, 0, length($fn)-length($1)) unless defined $flags->{KEEP_DATE};
          last;
        } elsif ( $fn =~ /\(($month)[. ](\d\d\d\d)\)/i) {
		  $self->{MONTH} = $1;
		  $self->{YEAR} = $2;
		  $fn =~ s/\($1[. ]$2\)// unless defined $flags->{KEEP_DATE};
		  last;
		}
      }
    }

    # If we found a year but no month, then likely the year is part
    # of the title, so we put it back.
##    if( $self->{YEAR} && !$self->{MONTH} && !$year_no_keep )
##    {
##      # Heuristic: If there is ANOTHER year (earlier on), we've
##      # probably got the right one after all. Else, put the one found back for safety.
##      if($fn !~ /([12][0-9][0-9][0-9])/ ) {
##        $fn .= " ".$self->{YEAR};
##        push(@{$self->{WARNINGS}}, "Year likely part of title");
##      }
##    }

    # Eat whitespace and dots at the back
    $fn =~ s/[\s.]*$//;

    # Find edition
    if( $fn =~ s/[\s.]*\(?(\d+)(st|nd|rd|th).ed(?:ition)?\)?$//i )
    {
      $self->{EDITION} = $1.lc($2);
    }

    # Convert dots to spaces
    $fn =~ s/\.(\D)/ $1/g;

    # Convert dots to spaces
    $fn =~ s/([^\d])\./$1 /g;

    # Post-Globals
    while( (my $replacement, my $pattern) = each(%globals_post) )
    {
      $fn =~ s/$pattern/$replacement/g;
    }

    # Eat whitespace and dots at the back
    $fn =~ s/[\s.]*$//;

    $self->{TITLE} = $fn;
}

sub publisher {
    my $self = shift;
    return $self->{PUBLISHER};
}

sub title {
    my $self = shift;
    return $self->{TITLE};
}

sub year {
    my $self = shift;
    return $self->{YEAR};
}

sub isbn {
    my $self = shift;
    return $self->{ISBN};
}

sub edition {
    my $self = shift;
    return $self->{EDITION};
}

sub ext {
    my $self = shift;
    return $self->{EXT};
}

sub warnings {
    my $self = shift;
    return defined $self->{WARNINGS} ? @{$self->{WARNINGS}} : ( );
}

sub regress_data {
    my $self = shift;
    my $s = "";
    my $lb = "{";
    my $rb = "}";

    $s .= $lb.$self->{ISBN}.$rb;
    $s .= $lb.$self->{YEAR}.$rb;
    $s .= $lb.$self->{PUBLISHER}.$rb;
    $s .= $lb.$self->{TITLE}.$rb;
    $s .= $lb.$self->{EXT}.$rb;
    $s .= $lb.$self->{EDITION}.$rb;
    $s .= $lb.( defined $self->{WARNINGS} ? scalar @{$self->{WARNINGS}} : 0 ).$rb;
    if(defined $self->{WARNINGS}) {
      $s .= $lb."W:".join(",",@{$self->{WARNINGS}}).$rb; # if @{$self->{WARNINGS}} > 0;
    }
    return $s;
}

sub DESTROY {
    my $self = shift;
}

return 1;
