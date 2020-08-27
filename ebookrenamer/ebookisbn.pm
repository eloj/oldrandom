#
# ebookisbn package
# (C)2008 Eddy L O Jansson <eddy@klopper.net>
#
# Example:
#
#
package ebookisbn;
use strict;


# Returns true if a 10-symbol string is a valid ISBN-10
sub is_isbn_10 {
   my $s = shift;
   my $sum = 0;

   if( length($s) == 10 )
   {
     for(my $i = 0 ; $i < 9 ; ++$i)
     {
       $sum += (10-$i) * substr($s, $i, 1);
     }
     $sum += uc(substr($s, 9, 1)) eq "X" ? 10 : substr($s, 9, 1);
     return 1 if( $sum % 11 == 0 );
   }

   return 0;
}

# Returns true if a 13-symbol string is a valid ISBN-13
sub is_isbn_13 {
   my $s = shift;
   my $sum = 0;

   if( length($s) == 13 )
   {
     for(my $i = 0 ; $i < 12 ; ++$i)
     {
       $sum += ($i & 1 ? 3 : 1) * substr($s, $i, 1);
     }
     $sum = 10 - ($sum % 10);
     return 1 if( $sum == substr($s, 12, 1) );
   }

   return 0;
}


# Returns true if a N-symbol string for N in { 10, 13 } is a valid ISBN-N.
# Obviously, input should be clean of hypens and whitespace.
sub is_isbn {
    my $s = shift;
    my $len = length($s);

    if($len == 10)
    {
      return is_isbn_10($s);
    } elsif ($len == 13) {
      return is_isbn_13($s);
    }

    return 0;
}


# Given a string, remove all ISBNs found in it, and returns the last one found.
# to-do: Should just push all found and return an array.
sub find_and_remove_isbn(\$) {

   my $sref = shift;
   my $i = 0;
   my $max_i = length($$sref);
   my $isbn_result = "";
   my $done = 0;

   while( ($i < $max_i) && (!$done) )
   {
     my $c = uc substr($$sref, $i, 1);
     if( ($c ge "0") && ($c le "9") || ($c eq "X") )
     {
        my $start_i = $i;
        my $isbn = "";
        while( !$done && (($c ge "0") && ($c le "9") || ($c eq "X") || ($c eq "-") || ($c eq " ") ) )
        {
          $isbn .= $c if ( ($c ne "-") && ($c ne " ") );
          $c = substr($$sref, ++$i, 1);
          if( $i > $max_i ) { $done = 1; }
        }
        if( is_isbn($isbn) ) # Check ISBN, and if found, remove it from input.
        {
           $isbn_result = $isbn;
           substr($$sref, $start_i, $i-$start_i) = ''; # Remove ISBN.
	   $max_i -= $i-$start_i;
           $i = $start_i;
        } else {
          $i = $start_i + 1;
        }
     } else {
       ++$i;
     }
   }

   return $isbn_result;
}

return 1;
