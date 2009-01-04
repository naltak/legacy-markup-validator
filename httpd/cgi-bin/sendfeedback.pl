#!/usr/bin/perl -T
##
## feedback generator for W3C Markup Validation Service
# # $Id: sendfeedback.pl,v 1.10 2009-01-04 16:54:19 ville Exp $

## Pragmas.
use strict;
use warnings;


## Modules.  See also the BEGIN block further down below.

use CGI                   qw();
use File::Spec::Functions qw(catfile);
use HTML::Template   2.6  qw();
use Config::General  2.31 qw(); # Need 2.31 for (partial) <msg 0> sanity

use vars qw($DEBUG $CFG $RSRC $VERSION $HAVE_IPC_RUN);
# Define global constants
use constant TRUE  => 1;
use constant FALSE => 0;

# Things inside BEGIN don't happen on every request in persistent
# environments, such as mod_perl.  So let's do globals, eg. read config here.
BEGIN {
  # Launder data for -T; -AutoLaunder doesn't catch this one.
  if (exists $ENV{W3C_VALIDATOR_HOME}) {
    $ENV{W3C_VALIDATOR_HOME} =~ /^(.*)$/;
    $ENV{W3C_VALIDATOR_HOME} = $1;
  }

  #
  # Read Config Files.
  eval {
    my %config_opts = (
       -ConfigFile => ($ENV{W3C_VALIDATOR_CFG} || '/etc/w3c/validator.conf'),
       -MergeDuplicateOptions => TRUE,
       -MergeDuplicateBlocks  => TRUE,
       -SplitPolicy      => 'equalsign',
       -UseApacheInclude => TRUE,
       -IncludeRelative  => TRUE,
       -InterPolateVars  => TRUE,
       -AutoLaunder      => TRUE,
       -AutoTrue         => TRUE,
       -DefaultConfig    => {
          Paths => {
            Base => ($ENV{W3C_VALIDATOR_HOME} || '/usr/local/validator'),
          },
       },
      );
    my %cfg = Config::General->new(%config_opts)->getall();
    $CFG = \%cfg;
  };
  if ($@) {
    die <<".EOF.";
Could not read configuration.  Set the W3C_VALIDATOR_CFG environment variable
or copy conf/* to /etc/w3c/. Make sure that the configuration file and all
included files are readable by the web server user. The error was:\n'$@'
.EOF.
  }
} # end of BEGIN block.

#
# Get rid of (possibly insecure) $PATH.
delete $ENV{PATH};

our $q = new CGI;
our $lang = 'en_US'; # @@@ TODO: conneg

# Read error message + explanations file
our %rsrc = Config::General->new(
  -MergeDuplicateBlocks => 1,
  -ConfigFile => catfile($CFG->{Paths}->{Templates}, $lang,
                         'error_messages.cfg'),
  )->getall();
# Config::General 2.31 workaround for <msg 0> issues:
# http://lists.w3.org/Archives/Public/public-qa-dev/2006Feb/0022.html
# http://lists.w3.org/Archives/Public/public-qa-dev/2006Feb/0025.html
# https://rt.cpan.org/Public/Bug/Display.html?id=17852
$rsrc{msg}{0} ||=
  { original => delete($rsrc{msg}{original}),
    verbose  => delete($rsrc{msg}{verbose}),
  };
$RSRC = \%rsrc;

our $T = HTML::Template->new(
  filename => catfile($CFG->{Paths}->{Templates}, $lang, 'feedback.tmpl'),
  die_on_bad_params => FALSE,
);

our $errlist = "";
our $errmsg_text;
our $validated_uri;
our $errmsg_id;

sub process_query {
    $validated_uri = $q->param('uri');
    $errmsg_id = $q->param('errmsg_id');
    if ($errmsg_id) {
        $errmsg_text = "$RSRC->{msg}->{$errmsg_id}->{original}";
        $errmsg_text = de_template_explanation($errmsg_text);
    }
    # Trigger "thanks for your message. If your query requires an answer,..." ack paragraph
    my $sent = $q->param('send');
    if ($sent) {
        print "hello";
        if ($sent == "yes") { $T->param(ack_ok => TRUE); }
    }
}

sub send_message {
# sends message to www-validator list @@ TODO @@
}

sub error_choices {
# creates drop-down menu with all possible error messages to send feedback about
    my @msgnumbers = keys( %{$RSRC->{msg}} );
    @msgnumbers = sort { $a <=> $b } @msgnumbers;
    my $errlabel;

    for my $errnum ( @msgnumbers ) {
        $errlabel = $RSRC->{msg}->{$errnum}->{original};
        $errlabel = de_template_explanation($errlabel);
	if (length($errlabel) > 70) { $errlabel = substr($errlabel, 0, 67)."..." }
        $errlist = $errlist.'<option value="'. $errnum.'"';
        if ($errmsg_id) {
            if ($errnum == $errmsg_id) { $errlist = $errlist.'selected="selected" '; }
        }
        $errlist = $errlist."> $errnum $errlabel</option>\n";
    }
}


sub de_template_explanation {
# takes the error message template, and replace "template keywords" with real life keywords
    my $explanation = shift;
    if ($explanation){
        $explanation =~ s/\%1/X/;
        $explanation =~ s/\%2/Y/;
        $explanation =~ s/\%3/Z/;
        $explanation =~ s/\%4/a/;
        $explanation =~ s/\%5/b/;
        $explanation =~ s/\%6/c/;
    }
    return $explanation;
}


sub prepare_error_message {
# if the form sent contains errors (what kind exactly?)
# @@ TODO @@
}

sub print_prefilled_form {
    $T->param(page_title => "Feedback");
    $T->param(uri => $validated_uri);
    $T->param(errmsg_id => $errmsg_id);
#    $T->param(errlist => $errlist);
    $T->param(explanation => $errmsg_text);
    print $T->output;
}



process_query;
#error_choices;
print_prefilled_form;

# END
