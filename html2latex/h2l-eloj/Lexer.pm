#
# Lexer
# (C)2006 Eddy L O Jansson <eddy@klopper.net>
#
# History
# ===================================================================
# 2006-03-23  eloj  Submitted version.
# 2006-03-23  eloj  \n is now properly returned as a single token
#
#
# To-Do
# ===================================================================
#  *

package Lexer;
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
   $self->{scanner} = shift;

   bless ($self, $class);
   return $self;
 }

 ### --- methods ---

 #
 # ** to-do: change to return internal flag instead.
 #
 sub done
 {
   my $self = shift;

   return $self->{scanner}->done();
 }
 sub get_until
 {
   my $self = shift;
   my $ch = shift;

   my $pattern = '[^'.$ch.']';
   my $lexeme = "";

   while( $self->{scanner}->peekch() =~ m/$pattern/ )
   {
     $lexeme .= $self->{scanner}->getch();
   }
   return $lexeme;
 }

 # Returns the next lexeme
 #
 # Pass in '1' in order to split on whitespace.
 #
 sub get
 {
   my $self = shift;
   my $split_on_ws = shift;

   # If splitting on whitespace, return only one "token" per whitespace-run.
   if( ($split_on_ws == 1) && $self->{scanner}->is_whitespace($self->{scanner}->peekch()) )
   {
     $self->skipws();
     return " ";
   }

   my $lex_chars = '<=>\-!\/\n';

   # Build reg-exp patterns.
   my $lex_pattern_1 = '['.$lex_chars.']';
   my $lex_pattern_2 = '[^ '.$lex_chars.']';
   my $lex_pattern_3 = '[^'.$lex_chars.']';

   # These are single character lexemes ("tokens") we're especially interested in.
   if( $self->{scanner}->peekch() =~ m/$lex_pattern_1/ )
   {
     return $self->{scanner}->getch();
   }

   # For the rest, collect characters until whitespace or one of our special lexemes.
   my $token = "";
   if( $split_on_ws )
   {
     while( $self->{scanner}->peekch() =~ m/$lex_pattern_2/ )
     {
       $token .= $self->{scanner}->getch();
     }
   } else {
     while( $self->{scanner}->peekch() =~ m/$lex_pattern_3/ )
     {
       $token .= $self->{scanner}->getch();
     }
   }

   return $token;
 }

 # Returns true if lookahead points to the supplied lexeme, else false.
 sub expect
 {
   my $self = shift;
   my $match = shift;

   if( length($match) == 1 )
   {
     return ($match eq $self->{scanner}->peekch()); # ? 1 : 0;
   } else {
     $self->{scanner}->push_state();
     # for loop which checks each char in $match against scanner,
     # until mismatch, or complete match.
     print "Lexer.pm::expect(string) -- **NOT YET IMPLEMENTED**";
     $self->{scanner}->pop_state();
     return 0;
   }
 }

 # If lookahead is whitespace, eat it. Else do nothing.
 sub skipws
 {
   my $self = shift;

   while( $self->{scanner}->is_whitespace($self->{scanner}->peekch()) )
   {
     $self->{scanner}->getch();
   }
 }

 sub eat
 {
   my $self = shift;
   return $self->{scanner}->getch();
 }

 sub position
 {
   my $self = shift;
   return $self->{scanner}->position();
 }


 sub debug
 {
   my $self = shift;
   print "-- Lexer debugging output --\n";
   #$self->{scanner}->debug();
 }

 return 1;
