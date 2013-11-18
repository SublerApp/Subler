# Copyright (c) 2008 Behan Webster. All rights reserved. This program is free
# software; you can redistribute it and/or modify it under the same terms
# as Perl itself.

package Debug::Simple;

use strict;
require Exporter;
use Data::Dumper;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

use vars qw(@EXPORT @ISA $VERSION);

$VERSION = "0.10";
@ISA = qw(Exporter);
@EXPORT  = qw(debuglevels warning debug verbose test);

my $opt;

###############################################################################
sub debuglevels {
	# Needs to have the keys: quiet, debug, verbose, test
	($opt) = @_;
	&debug(5, "Command line options: ", OPTS => $opt);
}

###############################################################################
sub _list {
	return (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;
}

###############################################################################
sub warning {
	return if $opt->{quiet};
	#warn ("Warning: ", @_);
	print YELLOW ("Warning: ", @_);
	print "";
}

###############################################################################
sub debug {
	return if $opt->{quiet};
	my @level = (&_list(shift), 0, 0, 0);

	return unless  (defined $opt->{debug} && $level[0] <= $opt->{debug})
				|| ($opt->{verbose} && $level[1] && $level[1] <= $opt->{verbose})
				|| ($opt->{test} && $level[2]);

	#print "DEBUG\n" if defined $opt->{debug} && $level[0] <= $opt->{debug};
	#print "VERBOSE: $opt->{verbose} && $level[1]\n" if defined $opt->{verbose} && $level[1] <= $opt->{verbose};
	#print "TEST\n" if defined $opt->{test} && $level[3];

	my $str = shift || '';
	my $name = shift;

	print BOLD "Debug: " unless $level[1] || $level[2];
	print BOLD "$str";
	if ($name && @_) {
		my $save = $Data::Dumper::Varname;
		$Data::Dumper::Varname = $name;
		print BOLD Dumper(@_);
		$Data::Dumper::Varname = $save;
	}
	print "";
}

###############################################################################
sub verbose {
	return if $opt->{quiet};
	my @level = (&_list(shift), 0, 0);

	return unless  ($opt->{verbose} && $level[0] && $level[0] <= $opt->{verbose})
				|| ($opt->{test} && $level[1]);

	print @_;
	print "";
}

###############################################################################
sub test {
	my $code = shift;
	my $str = shift || $code;

	if ($opt->{test}) {
		print CYAN "$str\n";
	} else {
		eval $code;
		print MAGENTA "Eval failed: $@\n" if $@;
		return $@;
	}
	print "";
}

1;
###############################################################################
__END__

=head1 NAME

Debug::Simple - Very simple debugging statements

=head1 SYNOPSIS

    use Debug::Simple;

    my %opt = (quiet => 0, debug => 4, verbose => 1, test => 0);
    Debug::Simple::debuglevels(\%opt);

    warning("This is a warning\m");
    debug(1, "This is a level 3 debug message\n");
    debug(2, "This is a level 2 debug message with a Dump", NAME => \%opt);
    verbose(1, "This is a verbose message\n");
    test('print "test code"');

=head1 DESCRIPTION

This module provides a very simple way to provide debug/verbose/warning
messages.  It is also trivially controlled via Getopt::Long.

The idea is to be able to put a bunch of debugging print statements throughout
your code that you can enable or disable.

=over 4

=item debuglevels(\%OPT)

C<debuglevels> registers the hashref C<HASH> as the place to read values used 
to control whether text is output to the screen or not.  There are 4 values
read from this hash: quiet, debug, verbose, and test.

=over

=item quiet

If non-zero, this will repress all output from Debug::Simple

=item debug

This indicates the level of debug messages desired.  A debug
level of 4 prints all the debug messages from levels 1 to 4.

=item verbose

Like debug, this sets the level of verboseness. A verbose
level of 3 prints all verbose messages from 1 to 3.

=item test

If non-zero, the code passed to test() will be printed to the
screen instead of being executed.

=back

=item warning(STRING)

C<warning> prints the C<STRING> to stdout in YELLOW unless the "quiet" level is
non-zero (see C<debuglevels>). C<STRING> is prefaced with "Warning:".

=item debug(LEVEL, STRING, [NAME => REF])

C<debug> prints a debugging message to stdout as long as C<LEVEL> is at or below
the "debug" level. (see <debuglevels).

The debug message is printed in BOLD. It starts with "Debug: ", then C<STRING>,
and then optionally uses Data::Dumper to dump a data structure referred to by
C<REF>. C<NAME> is just a human readable name for C<REF> passed to Data::Dumper.

=item verbose(LEVEL, STRING)

C<verbose> prints C<STRING> to stdout as long as C<LEVEL> is at or below the
"verbose" level. (see C<debuglevels>).

=item test(CODE)

C<test> executes C<CODE> according to the "test" level. (see C<debuglevels>).
If the "test" level is non-zero the code is printed to stdout instead of being
executed.

=back

=head1 LEVELS

To make things marginally more useful, you can specify that a message can be
printed to stdout based on more than one level by specifying a list of levels.

For instance, for C<debug> you can also specify the "verbose" and "test" levels
at which the debug message will be printed. In the following example, the debug
message will be output at debug levels 1-2, verbose levels 1-3 or test level 1.

    &debug([2,3,1], "This is a debug message\n");

In this case, the message will be printed to stdout if the verbose level is 1-2
or test level 1.

    &verbose([2,1], "This is a verbose message\n");

=head1 EXAMPLE CODE

This example shows how Debug::Simple code can be tied in with GetOpt::Long.

    use Debug::Simple;
    use Getopt::Long;
    use Pod::Usage;

    pod2usage(2) unless GetOptions( $opt = {},
        qw(help debug:i quiet test verbose|v+) );
    pod2usage(1) if $opt->{help};
    $opt->{debug} = 1 if defined $opt->{debug} && !$opt->{debug};
    Debug::Simple::debuglevels($opt);

    debug(2, "Command line options ", OPT=>$opt);
    verbose(1, "Now on with the show\n");

    ...

=head1 AUTHOR

S<Behan Webster E<lt>behanw@websterwood.com<gt>>

=head1 COPYRIGHT

Copyright (c) 2004-2008 Behan Webster. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
