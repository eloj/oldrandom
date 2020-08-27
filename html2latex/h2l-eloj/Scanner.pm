package Scanner;
use strict;

 ##################################################
 ##            the object constructor            ##
 ##################################################
 sub new
 {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self  = {};

   # setup member data
   $self->{source} = shift;
   $self->{data} = "";

   $self->{pos_line} = 0;
   $self->{pos_col} = -1;

   if( $self->{source} )
   {
     open(IN, $self->{source});
     while(<IN>)  # Buffer all data
     {
       $self->{data} .= $_;
     }
     #$self->{data} .= "\n"; # ** safety-net sentinel
     close(IN);
   }

   $self->{lookpos} = 0;
   $self->{look} = substr($self->{data},0,1);

   bless ($self, $class);
   return $self;
 }

 ### --- member functions ---

 sub done
 {
   my $self = shift;

   return $self->{lookpos} >= length($self->{data});
 }

 sub setdata
 {
   my $self = shift;
   $self->{data} = shift;
   $self->{lookpos} = 0;
   $self->{look} = substr($self->{data},0,1);;
   $self->{pos_line}=0;
   $self->{pos_col}=-1;
 }

 sub peekch
 {
   my $self = shift;
   return $self->{look};
 }

 sub getch
 {
   my $self = shift;

   if( $self->{lookpos} >= length($self->{data}) ) { return undef; }

   # If previous character was a newline, step up the line counter.
   if($self->{look} eq "\n") # Keep track of line and col information.
   {
     ++$self->{pos_line};
     $self->{pos_col}=0;
   } else {
     ++$self->{pos_col};
   }

   my $ret = $self->{look};
   # Setup new lookahead character.
   $self->{look} = substr($self->{data},++$self->{lookpos},1);

   return $ret;
 }

 sub position
 {
   my $self = shift;
   return $self->{pos_col}.",".$self->{pos_line};
 }

 sub is_whitespace
 {
   my $self = shift;
   my $ch = shift;
   return $ch =~ m/[ \t]+/ ? 1 : 0;
 }

 #sub is_alphanum
 #{
 #  my $self = shift;
 #  my $ch = shift;
 #  return $ch =~ m/[\w\d]+/ ? 1 : 0;
 #}

 sub debug
 {
   my $self = shift;
   print "-- Scanner debugging output --\n";
   print "data: '".$self->{data}."'\n";
   print "data length: ".length($self->{data})."\n";
   print "current line: ".$self->{pos_line}."\n";
   print "current col : ".$self->{pos_col}."\n";
 }

 return 1;
