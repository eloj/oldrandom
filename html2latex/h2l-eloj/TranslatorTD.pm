#
# TranslatorTD (Table-Driven)
# (C)2006 Eddy L O Jansson <eddy@klopper.net>
#
# History
# ===================================================================
# 2006-03-19  eloj  Work began.
# 2006-03-23  eloj  Submitted version.
# 2006-03-23  eloj  Added more entities. Fixed bug in EOL-handling.
#
# To-Do
# ===================================================================
#
#  * Entity translation is fairly b0rken (see transform_entities())
#
#  * Refactor state and symtable into proper modules...
#    Should be able to do $self->parent()->sym_add("hej",1);
#
#  * ... and remove the obsolete hackery that is $self->{SYMTABLE}
#
#  * Update parse-table and parse_TITLE to use ACCUMULATE_IN_PARENT
#    instead of obsolete $self->{SYMTABLE}
#
#  * Track alignment for table columns.
#
#  * Comments should be accumulated and emitted at newline and eof.
#
#  * Have use of parser subs trigger inclusion of packages in h2l.pl
#    (parse_A makes h2l include hyperref, etc)
#
package Translator;

use strict;


 ##################################################
 ##            the object constructor            ##
 ##################################################
 sub new
 {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self  = {};
   bless ($self, $class);

   $self->{DEBUG_FLAG} = 0;

   # setup member data
   $self->{lex} = shift;
   $self->{num_errors} = 0;
   $self->{num_warnings} = 0;

   # "Symbol table" for title, author, unflushed comments...
   # this one is supposed to go away and data move into state stack.
   $self->{SYMTABLE} = { };
   $self->{DOC} = "";

   # Parser state transition table and metadata.
   $self->{PARSE_TABLE} = {
       ROOT => { FLAGS => { ALLOW_BAREWORDS => 0 },
                 STATES => {
                   "COMMENT" => { FUNC => \&parse_COMMENT },
                   "DOCTYPE" => { FUNC => \&parse_DTD },
                   "HTML" => { FUNC => \&parse_HTML, NEW_STATE => "HTML" }
                 }
               },
       HTML => { FLAGS => { ALLOW_BAREWORDS => 0 },
                 STATES => {
                   "COMMENT" => { FUNC => \&parse_COMMENT },
                   "HEAD" => { FUNC => \&parse_HEAD, NEW_STATE => "HEAD"  },
                   "BODY" => { FUNC => \&parse_BODY, NEW_STATE => "BODY"  },
                 }
               },
       HEAD => { FLAGS => { ALLOW_BAREWORDS => 0 },
                 STATES => {
                   "COMMENT" => { FUNC => \&parse_COMMENT },
                   "TITLE" => { FUNC => \&parse_TITLE },
                   #"SCRIPT" => { FUNC => \&parse_SINK },     # to-do: ** Add "SCRIPT" state with no rules and ALLOW_BARWORDS=1
                   "META" => { FUNC => \&parse_META },
                   #"STYLE" => { FUNC => \&parse_SINK },
                   #"LINK" => { FUNC => \&parse_SINK },
                 }
               },
       BODY => { FLAGS => { ALLOW_BAREWORDS => 0 },
                 STATES => {
                   "COMMENT" => { FUNC => \&parse_COMMENT },
                   "P" => { FUNC => \&parse_P, NEW_STATE => "P" },
                   "H1" => { FUNC => \&parse_H, NEW_STATE => "H1" },
                   "H2" => { FUNC => \&parse_H, NEW_STATE => "H2" },
                   "H3" => { FUNC => \&parse_H, NEW_STATE => "H3" },
                   "UL" => { FUNC => \&parse_LIST_UL, NEW_STATE => "UL" },
                   "PRE" => { FUNC => \&parse_PRE, NEW_STATE => "PRE" },
                   "CENTER" => { FUNC => \&parse_CENTER, NEW_STATE => "CENTER" },
                   "IMG" => { FUNC => \&parse_IMG },
                   "TABLE" => { FUNC => \&parse_TABLE, NEW_STATE => "TABLE" },
                 }
               },
       TABLE => { FLAGS => { ALLOW_BAREWORDS => 0 },
                 STATES => {
                   "TR" => { FUNC => \&parse_TR, NEW_STATE => "TR" },
                 }
               },
       TR => { FLAGS => { ALLOW_BAREWORDS => 0, ACCUMULATE_IN_PARENT => 1 },
                 STATES => {
                   "TD" => { FUNC => \&parse_TD, NEW_STATE => "TD" },
                 }
               },
       TD  => { FLAGS => { ALLOW_BAREWORDS => 1, ACCUMULATE_IN_PARENT => 1 },
                    STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                      #"BR" => { FUNC => \&parse_BR },
                      "A" => { FUNC => \&parse_A },
                     }
                },
       CENTER => { FLAGS => { ALLOW_BAREWORDS => 1 },
                 STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                      "BR" => { FUNC => \&parse_BR },
                      "IMG" => { FUNC => \&parse_IMG },
                 }
              },
       PRE => { FLAGS => { ALLOW_BAREWORDS => 1, PRESERVE_WHITESPACE => 1 },
                STATES => { }
              },
       UL => { FLAGS => { ALLOW_BAREWORDS => 0 },
                    STATES => {
                      "LI" => { FUNC => \&parse_LIST_LI, NEW_STATE => "LI" },
                      "UL" => { FUNC => \&parse_LIST_UL, NEW_STATE => "UL" },
                   }
               },
       LI => { FLAGS => { ALLOW_BAREWORDS => 1 },
                    STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                   }
               },
       P => { FLAGS => { ALLOW_BAREWORDS => 1 },
                    STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                      "BR" => { FUNC => \&parse_BR },
                      "A" => { FUNC => \&parse_A },
                      "IMG" => { FUNC => \&parse_IMG },
                   }
               },
       H1 => { FLAGS => { ALLOW_BAREWORDS => 1 },
                    STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                   }
               },
       H2 => { FLAGS => { ALLOW_BAREWORDS => 1 },
                    STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                   }
               },
       H3 => { FLAGS => { ALLOW_BAREWORDS => 1 },
                    STATES => {
                      "I" => { FUNC => \&parse_I },
                      "B" => { FUNC => \&parse_B },
                      "EM" => { FUNC => \&parse_EM },
                      "TT" => { FUNC => \&parse_TT },
                      "SUP" => { FUNC => \&parse_SUP },
                      "SUB" => { FUNC => \&parse_SUB },
                   }
               },


   };

   $self->{STATE_STACK} = ();
   $self->{STATE_STACK_PTR} = 0;
   $self->push_state("ROOT");
   return $self;
 }


 ### --- methods ---
 sub error
 {
   my $self = shift;
   my $error_message = shift;
   print STDERR "Error: ".$error_message."\n";
   ++$self->{num_errors};
   return 0;
 }

 sub warning
 {
   my $self = shift;
   my $warning_message = shift;
   print STDERR "Warning: ".$warning_message."\n";
   ++$self->{num_warnings};
   return 0;
 }

 sub debug
 {
   my $self = shift;
   my $msg = shift;
   print STDERR $msg if $self->{DEBUG_FLAG} > 0;
 }

 # to-do: ** Don't have the time to do this properly.
 #
 sub transform_entities
 {
   my $s = shift;
   my %entities_h2l = (
    #'LaTeX' => '\LaTeX',
    '\^'    => '\\^\ ',  # This isn't good
    '{'    => '\\{',
    '}'    => '\\}',
    #'&'     => '\\&',   # Shouldn't be needed, but is IRL.
    #'\$'    => '\\$',   # needs to be rewritten to not clash with $<$ and $>$
    '%'     => '\\%',
    '#'     => '\\#',
    '_'     => '\\_',
    '&copy;'=> '\copyright',
    '&nbsp;'=> ' ',
    '&amp;' => '\\&',
    '&lt;'  => '$<$',
    '&gt;'  => '$>$',
    '&quot;'=> '\'\'',
    '"'     => '\'\'',
   );

   while( my ($src,$dest) = each (%entities_h2l) )
   {
     $s =~ s/$src/$dest/ig;
   }

   return $s;
 }

 sub push_state
 {
   my $self = shift;
   my $state = shift;
                                                                                         # , SYMTABLE => {}
   push( @{$self->{STATE_STACK}}, { STATE => $state, DOC => $self->{DOC}, ACCBUFFER => () } );
   ++$self->{STATE_STACK_PTR};
   $self->{DOC} = ""; # new context
   $self->debug("Pushed state ".$state." (".$self->{STATE_STACK_PTR}.")\n");
 }

 sub pop_state
 {
   my $self = shift;

   my $state_hash = pop(@{$self->{STATE_STACK}});
   #my ($state, $prev_doc) = pop(@{$self->{STATE_STACK}});
   my $state = $state_hash->{STATE};
   --$self->{STATE_STACK_PTR};
   # Set current document to previous + current.
   $self->{DOC} = $state_hash->{DOC}.$self->{DOC};
   $self->debug("Popped state ".$state." (".$self->{STATE_STACK_PTR}.")\n");
 }

 # Returns the name of the current state.
 sub current_state
 {
   my $self = shift;
   return $self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-1]->{STATE};
 }

 # Returns the name of the previous state.
 sub previous_state
 {
   my $self = shift;
   return $self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-2]->{STATE};
 }

 # Accumulate data in parent state.
 sub accumulate_in_parent
 {
   my $self = shift;
   my $doc = shift;

   push ( @{$self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-2]->{ACCBUFFER}}, $doc);
 }

 # Add a key and value to the symboltable of the previous state.
 sub sym_add_to_parent
 {
   my $self = shift;
   my $key = shift;
   my $value = shift;

   $self->debug("Adding '".$key."' => '".$value."' to parent\n");
   $self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-2]->{SYMTABLE}->{$key} = $value;
 }

 # Given a key, get its value in the current state.
 sub sym_get
 {
   my $self = shift;
   my $key = shift;
   return $self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-1]->{SYMTABLE}->{$key};
 }

 # Hackery to encode comments
 sub emit_comment
 {
   my $self = shift;
   my $s = shift;

   chomp $s; # ** to-do: remove any starting whitespace/newlines also
   # Replace any newlines with newline+comment marker
   $s =~ s/\n/\n% /g;
   return "% ".$s;
 }

#===================================================================
#
# The following are the main output generating parse methods,
# they are invoked from the main parser loop with the current
# tag passed along.
#
#===================================================================

 sub parse_HEAD()
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   if( $tag->is_closetag() )
   {
     $doc = "\n".'\title{'.transform_entities($self->{SYMTABLE}{TITLE}).'}'."\n";
     if( defined $self->{SYMTABLE}{AUTHOR} )
     {
       $doc .= '\author{'.transform_entities($self->{SYMTABLE}{AUTHOR}).'}'."\n";
     }
   }

   return $doc;
 }

 sub parse_DTD
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   $doc .= $self->emit_comment($tag->get_attribute("=DTD"));
   return $doc;
 }

 sub parse_COMMENT
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   $doc .= $self->emit_comment($tag->get_attribute("=COMMENT"));
   return $doc;
 }

 sub parse_TITLE
 {
   my $self = shift;
   my $tag = shift;

   if( !$tag->is_closetag() )
   {
     $self->{SYMTABLE}{TITLE} = $self->{lex}->get_until('<');
   }

   return "";
 }

 sub parse_HTML
 {
   my $self = shift;
   my $tag = shift;

   return "";
 }

 sub parse_META
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   if( uc $tag->get_attribute("NAME") eq "AUTHOR" ) # accumulate authors
   {
     $self->{SYMTABLE}{AUTHOR} .= ( $self->{SYMTABLE}{AUTHOR} ? ' \and ' : "").$tag->get_attribute("CONTENT");
   }

   return $doc;
 }

 sub parse_BODY
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   if( $tag->is_closetag() )
   {
     $doc .= "\n\n".'\end{document}'."\n";
   } else {
     $doc .= "\n".'\begin{document}'."\n".'\maketitle'."\n\n";
   }

   return $doc;
 }

 sub parse_A
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '}' : '\href{'.$tag->get_attribute("HREF").'}{';
 }

 #
 # ** to-do: get width/height/alt/title from symtable and use them.
 #
 sub parse_IMG
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '' : '\includegraphics[scale=1.0]{'.$tag->get_attribute("SRC").'}';
 }

 sub parse_H
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";
   my $level = substr($tag->name(), -1);

   my @mapping = ( "", "section", "subsection", "subsubsection", "paragraph", "subparagraph" );

   if( !$tag->is_closetag() )
   {
     $doc .= "\n\n".'\\'.$mapping[ $level ].'{';  # min($level, @mapping)
   } else {
     $doc .= "}\n\n";
   }

   return $doc;
 }

 sub parse_PRE
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '\end{verbatim}' : '\begin{verbatim}';
 }

 sub parse_CENTER
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '\end{center}' : '\begin{center}';
 }

 # ** to-do: fix to only output if necessary, for a nicer source document.
 sub parse_P
 {
   my $self = shift;
   my $tag = shift;

   return "\n\n";
 }

 sub parse_BR
 {
   my $self = shift;
   my $tag = shift;
   return $tag->is_closetag() ? "" : " \\\\ ";
 }

 # outputting \textrm escapes math-mode, which is probably
 # a good idea even though it makes x<sup>2</sup> look worse.
 sub parse_SUP
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '}}$' : '$^{\textrm{';
 }

 sub parse_SUB
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '}}$' : '$_{\textrm{';
 }


 sub parse_I
 {
   my $self = shift;
   my $tag = shift;

    return $tag->is_closetag() ? '}' : '\textit{';
 }

 sub parse_EM
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '}' : '\emph{';
 }
 
 sub parse_TT
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '}' : '\texttt{';
 }

 sub parse_B
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '}' : '\textbf{';
 }


 sub parse_LIST_UL
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? '\end{itemize}' : '\begin{itemize}';
 }

 sub parse_LIST_LI
 {
   my $self = shift;
   my $tag = shift;

   return $tag->is_closetag() ? "\n" : '\item ';
 }

 sub parse_TABLE
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   if( $tag->is_closetag() )
   {
     $doc .= '\begin{tabular}{';
     $doc .= 'l' x $self->sym_get("COLUMNS"); # to-do: get alignment from symtable
     $doc .= "}\n";

     # to-do: ACCBUFFER access should move behind an API
     foreach my $line (@{$self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-1]->{ACCBUFFER}})
     {
       $doc .= $line." \\\\\n";
     }
     $doc .= '\end{tabular}';

   }
   return $doc;
 }


 sub parse_TR
 {
   my $self = shift;
   my $tag = shift;
   my $doc = "";

   #$self->sym_get("ACCBUFFER");
   if( $tag->is_closetag() )
   {
     $doc .= join(" & ", @{$self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-1]->{ACCBUFFER}} );
     $self->sym_add_to_parent("COLUMNS", scalar @{$self->{STATE_STACK}->[$self->{STATE_STACK_PTR}-1]->{ACCBUFFER}});
   }
   return $doc;
 }

 sub parse_TD
 {
   my $self = shift;
   my $tag = shift;
   return "";
 }

#===================================================================
# ... end of parse_SUBs
#===================================================================




 #
 # "main"
 #
 sub run()
 {
   my $self = shift;
   my $tag;
   my $lexeme;

   # As long as we have something to process..
   while( !$self->{lex}->done() )
   {
     if( $self->{PARSE_TABLE}->{$self->current_state()}->{FLAGS}->{ALLOW_BAREWORDS} == 0 ) # Skip whitespace between tags
     {
       $self->{lex}->skipws();
     }

     if( $self->{PARSE_TABLE}->{$self->current_state()}->{FLAGS}->{PRESERVE_WHITESPACE} == 1 )
     {
       $lexeme = $self->{lex}->get(); # Preserve whitespace
     } else {
       $lexeme = $self->{lex}->get(1); # split on whitespace
     }

     #print $lexeme.";";

     if($lexeme eq "<") # If we see a tag ...
     {
       $tag = ParseTag->new($self->{lex});

       if( !$tag->ok() ) { $self->error("Ah, crap. Tag '".$tag->name()."' not parsed ok? Aborting."); return ""; }

       # Figure out if we're leaving the current state, in which case we run any exit sub and pop the state stack.
       if( $tag->is_closetag() && (uc $tag->name()) eq $self->current_state())
       {
          my $func_state = $self->current_state();
          my $chk_state = $self->previous_state();

          # Now we want to call the parse-function with the closing tag for the previous state in the new one.
          if( exists $self->{PARSE_TABLE}->{$chk_state}->{STATES}->{$func_state}->{FUNC} )
          {
            $self->{DOC} .= $self->{PARSE_TABLE}->{$chk_state}->{STATES}->{$func_state}->{FUNC}($self, $tag);
          }

          if( $self->{PARSE_TABLE}->{$func_state}->{FLAGS}->{ACCUMULATE_IN_PARENT} == 1 )
          {
            $self->accumulate_in_parent( $self->{DOC} );
            $self->{DOC} = "";
          }

          $self->pop_state();

       } else {

         # Check it there is a rule-set for the current state in the parse table.
         if( defined $self->{PARSE_TABLE}->{$self->current_state()}->{STATES} )
         {
           my $value = $self->{PARSE_TABLE}->{$self->current_state()};

           # We have a rule-set, but is there a rule for the current tag in there?
           if( defined $value->{STATES}->{uc $tag->name()} )
           {
             my $svalue = $value->{STATES}->{uc $tag->name()};

             $self->debug("Parsing state ".$self->current_state()."->".(uc $tag->name())." with ".($tag->is_closetag() ? "close-" : "")."tag '".$tag->name()."'\n");

             if( defined $svalue->{NEW_STATE} )
             {
               $self->push_state( $svalue->{NEW_STATE} );
             }

             if( defined $svalue->{FUNC} )
             {
               $self->{DOC} .= $svalue->{FUNC}($self,$tag);
             }

           } else {
             $self->warning("Skipping unexpected tag '".$tag->name()."' at ".$self->{lex}->position()); # Position is end of tag.
           }
         } else {
           $self->error("Eeeeh? We entered a state '".$self->current_state()."' for which there is no rule set! Aborting.");
           return "";
         }

       } # else ... bla bla close tag state.

     } else {
       # If ALLOW_BAREWORDS, then keep data between tags, unless newline.
       if( $self->{PARSE_TABLE}->{$self->current_state()}->{FLAGS}->{ALLOW_BAREWORDS} == 1 ) # $lexeme ne "\n" &&
       {
         # print "::".$lexeme."::";
         $self->{DOC} .= transform_entities($lexeme);
       } else {
         $self->warning("Bareword '".$lexeme."' skipped at ".$self->{lex}->position()) if( $lexeme ne "\n" );
       }
     }

   }

   return $self->{DOC};
 }

 return 1;
