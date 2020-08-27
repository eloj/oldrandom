#
# ParseTag
# (C)2006 Eddy L O Jansson <eddy@klopper.net>
#
# History
# ===================================================================
# 2006-03-19  eloj  Comments are finally to spec.
# 2006-03-21  eloj  Support quoted values.
# 2006-03-23  eloj  Submitted version.
#
#
# To-Do
# ===================================================================
#  * DTD/Comment/normal comment needs to be refactored into individual
#    functions.
#
#  * Replace ->get()-calls with ->eat() where appropriate.
#
#  * Store tag start position (lexer) and return it for ->position()
#
package ParseTag;
use strict;

 sub new
 {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self  = {};
   bless ($self, $class);

   # setup member data
   my $lexer = shift;

   $self->{name} = "";
   $self->{attrs} = { };
   $self->{is_comment} = 0;
   $self->{is_DTD} = 0;
   $self->{is_closetag} = 0;
   $self->{parse_ok} = 1;

   # get tag name
   $self->{name} = $lexer->get(1);
   $lexer->skipws();

   # if $self->{name} = '/' then closing tag, so no need to parse attrs
   if( $self->{name} eq "/" )
   {
     $self->{is_closetag} = 1;
     $self->{name} = $lexer->get(1);
     $lexer->skipws();
     if( !$lexer->expect(">") ) # We're expecting a close tag, else error.
     {
       $self->{parse_ok} = 0;
     } else {
       $lexer->get(); # consume end-tag
     }
   }
   elsif( $self->{name} eq "!" ) # this is a comment or DOCTYPE tag
   {
     $lexer->skipws(); # We'll allow ws before the DTD or start-comment marker. This is against 3.2.4 of REC-html401

     # SGML:
     #if( $lexer->expect(">") ) # This satisfies the empty comment: "<!>"
     #{
     #  $self->{is_comment} = 1;
     #  return $self;
     #}

     # A comment starts and ends with "--", and does not contain any occurrence of "--"
     #
     if( $lexer->expect("-") ) # We've seen <!-
     {
       $self->{name} = "comment";
       $lexer->get();

       # Second '-' marks the comment start
       if( $lexer->expect("-") )
       {
         $self->{is_comment} = 1;
         $lexer->get(); # eat start of comment.
         my $comment_done = 0;

         while( !$comment_done )
         {
           # Add to comment until '--' which ends comment.
           while( !$lexer->expect("-") )
           {
             $self->{attrs}{"=COMMENT"} .= $lexer->get();
           }
           $lexer->get(); # eat '-'
           if( $lexer->expect("-") ) # two '-' in a row, so we're out of the comment.
           {
             $lexer->get();
             $comment_done = 1; # break loop
           } else {
             $self->{attrs}{"=COMMENT"} .= "-"; # Wasn't part of end-comment marker, so we'll keep it.
           }
         }

       } else {
         $self->{is_comment} = 0;
         $self->{parse_ok} = 0;
         # return $self; # We fall through and let the parser sync up to the next close-tag.
       }

       # Collect until close-tag.
       while( !$lexer->expect(">") )
       {
         $lexer->get(); # just eat away.
       }
     }
     elsif ( $lexer->expect("D") ) # It likely a DTD.
     {
       $self->{name} = $lexer->get(1);
       if( $self->{name} eq "DOCTYPE" )
       {
         $self->{is_DTD} = 1;
         $self->{parse_ok} = 1;

         # Collect until close-tag.
         while( !$lexer->expect(">") )
         {
           $self->{attrs}{"=DTD"} .= $lexer->get();
         }

       } else {
         $self->{parse_ok} = 0;
       }
     } else { # If not !-- nor !DOCTYPE
       $self->{parse_ok} = 0;
       # $self->sync(); # ** to-do: Consume until close tag.
       return $self;
     }

     $lexer->eat(); # consume end-tag
   } else {
     #print "Parsing tag '".$self->{name}."'\n";
     while( !$lexer->expect(">") )
     {
       $lexer->skipws();
       my $attr = $lexer->get_until("=>");
       my $value = undef;
       # Attributes are either bare or followed by = value
       if( $lexer->expect("=") )
       {
         $lexer->eat(); # consume '='
         if( $lexer->expect('"') ) # parse '"some value here"'
         {
           $lexer->eat(); # consume '"'
           $value = $lexer->get_until('"');
           $lexer->eat(); # consume '"'
         } else {
           $value = $lexer->get(1);
         }
       }

       # store $attr and $value in class:
       $self->{attrs}{uc $attr} = $value;      # to-do: ** fix case?
     }
     $lexer->get(); # consume end-tag
   }
   return $self;
 }

 ### --- methods ---
 sub ok()
 {
   my $self = shift;
   return $self->{parse_ok};
 }

 sub is_closetag()
 {
   my $self = shift;
   return $self->{is_closetag};
 }

 sub name()
 {
   my $self = shift;
   return lc $self->{name};
 }

 sub has_attribute()
 {
   my $self = shift;
   print "** ParseTag::has_attribute() NOT IMPLEMENTED **";
   return 0;
 }

 sub get_attribute()
 {
   my $self = shift;
   my $attr = shift;

   #if( $self->has_attribute($attr) )
   return $self->{attrs}{uc $attr};
 }


 sub debug
 {
   my $self = shift;

   # dump all attributes
   print "Parsed OK: ".$self->{parse_ok}."\n";
   print "is_closetag: ".$self->{is_closetag}."\n";
   print "is_comment: ".$self->{is_comment}."\n";
   print "is_DTD: ".$self->{is_DTD}."\n";
   print "Tag name: '".$self->{name}."'\n";
   print "Tag attributes:\n";
   while ( (my $key, my $value) = each( %{$self->{attrs}} )  )
   {
     print " '".$key."' => '".$value."'\n";
   }

 }

 return 1;
