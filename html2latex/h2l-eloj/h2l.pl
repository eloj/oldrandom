#!/usr/bin/perl

# HTML-2-LaTeX CT3370 Simple Driver
# (C)2006 Eddy L O Jansson <eddy@klopper.net>
#
# History
# ===================================================================
# 2006-03-19  eloj  Work began.
# 2006-03-23  eloj  Submitted version.
#
# To-Do
# ===================================================================
#
#  * Usage, options, etc.
#
use strict;
use Scanner;
use Lexer;
use ParseTag;
use TranslatorTD;

 my $scanner = Scanner->new('-'); # read from stdin
 my $lex = Lexer->new($scanner);
 my $translator = Translator->new($lex);

 my $doc =
  '\documentclass[a4paper,10pt]{article}'."\n".
  '\usepackage[latin1]{inputenc}'."\n".
  '\usepackage{graphicx}'."\n".
  '\usepackage[pdfpagemode=none,pdfstartview=FitH]{hyperref}'."\n".
  $translator->run();

 print $doc;
 print STDERR "Size of resulting document: ".length($doc)."\n";

 #$translator->debug();
