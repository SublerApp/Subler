# Copyright (c) 2008 Behan Webster. All rights reserved. This program is free
# software; you can redistribute it and/or modify it under the same terms
# as Perl itself.
# Modified 2010 by Douglas Stebila to support parentheses in movie years

package Video::Filename;

use strict;
require Exporter;

use Debug::Simple;
use Data::Dumper;
use Term::ANSIColor qw(:constants);
use Text::Roman qw(roman2int);
$Term::ANSIColor::AUTORESET = 1;

use vars qw($VERSION @filePatterns @testFuncs);

$VERSION = "0.35.1";

@filePatterns = (
	{ # DVD Episode Support - DddEee
		# Perl > v5.10
		re => '^(?:(?<name>.*?)[\/\s._-]+)?(?:d|dvd|disc|disk)[\s._]?(?<dvd>\d{1,2})[x\/\s._-]*(?:e|ep|episode)[\s._]?(?<episode>\d{1,2}(?:\.\d{1,2})?)(?:-?(?:(?:e|ep)[\s._]*)?(?<endep>\d{1,2}))?(?:[\s._]?(?:p|part)[\s._]?(?<part>\d+))?(?<subep>[a-z])?(?:[\/\s._-]*(?<epname>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]+)?(?:d|dvd|disc|disk)[\s._]?(\d{1,2})[x\/\s._-]*(?:e|ep|episode)[\s._]?(\d{1,2})(?:-?(?:(?:e|ep)[\s._]*)?(\d{1,2}(?:\.\d{1,2})?))?(?:[\s._]?(?:p|part)[\s._]?(\d+))?([a-z])?(?:[\/\s._-]*([^\/]+?))?$',
		keys_compat => [qw(name dvd episode endep part subep epname)],

		test_funcs => [1, 0, 1, 0], # DVD TV Episode Movie
		test_keys => [qw(filename name dvd episode endep part subep epname ext)],
		test_files => [
			['D01E02.Episode_name.avi', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.D01E02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/D01E02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/D01E02/Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.D01E02a.Episode_name.avi', 'Series Name', 1, 2, undef, undef, 'a', 'Episode_name', 'avi'],
			['Series Name.D01E02p4.Episode_name.avi', 'Series Name', 1, 2, undef, 4, undef, 'Episode_name', 'avi'],
			['Series Name.D01E02-03.Episode_name.avi', 'Series Name', 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name.D01E02-E03.Episode_name.avi', 'Series Name', 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name.D01E02E.03.Episode_name.avi', 'Series Name', 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name/D01E02E03/Episode_name.avi', 'Series Name', 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['D01E02E03/Episode name.avi', undef, 1, 2, 3, undef, undef, 'Episode name', 'avi'],
			['Series Name.DVD_01.Episode_02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.disk_V.Episode_XI.Episode_name.avi', 'Series Name', 5, 11, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.disc_V.Episode_XI.Part.XXV.Episode_name.avi', 'Series Name', 5, 11, undef, 25, undef, 'Episode_name', 'avi'],
			['Series Name.DVD01.Ep02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/dvd_01.Episode_02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/disk_01/Episode_02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/D.I/Ep02.Episode_name.avi', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/D three/Ep five Episode_name.avi', 'Series Name', 3, 5, undef, undef, undef, 'Episode_name', 'avi'],
		],
	},
	{ # TV Show Support - SssEee or Season_ss_Episode_ss
		# Perl > v5.10
		re => '^(?:(?<name>.*?)[\/\s._-]+)?(?:s|se|season|series)[\s._-]?(?<season>\d+)[x\/\s._-]*(?:e|ep|episode|[\/\s._-]+)[\s._-]?(?<episode>\d+)(?:-?(?:(?:e|ep)[\s._]*)?(?<endep>\d+))?(?:[\s._]?(?:p|part)[\s._]?(?<part>\d+))?(?<subep>[a-z])?(?:[\/\s._-]*(?<epname>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]+)?(?:s|se|season|series)[\s._-]?(\d+)[x\/\s._-]*(?:e|ep|episode|[\/\s._-]+)[\s._-]?(\d+)(?:-?(?:(?:e|ep)[\s._]*)?(\d+))?(?:[\s._]?(?:p|part)[\s._]?(\d+))?([a-z])?(?:[\/\s._-]*([^\/]+?))?$',
		keys_compat => [qw(name season episode endep part subep epname)],

		test_funcs => [0, 1, 1, 0], # DVD TV Episode Movie
		test_keys => [qw(filename name guess-name season episode endep part subep epname ext)],
		test_files => [
			['S01E02.Episode_name.avi', undef, undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.S01E02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/S01E02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/S01E02/Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series/Name/S01E02/Episode_name.avi', 'Name', 'Series Name', 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
            ['Series/Name/S01940E0237/Episode_name.avi', 'Name', 'Series Name', 1940, 237, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.S01E02a.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, 'a', 'Episode_name', 'avi'],
			['Series Name.S01E02p4.Episode_name.avi', 'Series Name', undef, 1, 2, undef, 4, undef, 'Episode_name', 'avi'],
			['Series Name.S01E02-03.Episode_name.avi', 'Series Name', undef, 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name.S01E02-E03.Episode_name.avi', 'Series Name', undef, 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name.S01E02E.03.Episode_name.avi', 'Series Name', undef, 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name/S01E02E03/Episode_name.avi', 'Series Name', undef, 1, 2, 3, undef, undef, 'Episode_name', 'avi'],
			['S01E02E03/Episode name.avi', undef, undef, 1, 2, 3, undef, undef, 'Episode name', 'avi'],
			['Series Name.Season_01.Episode_02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.Season_V.Episode_XI.Episode_name.avi', 'Series Name', undef, 5, 11, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.Season_V.Episode_XI.Part.XXV.Episode_name.avi', 'Series Name', undef, 5, 11, undef, 25, undef, 'Episode_name', 'avi'],
			['Series Name.Se01.Ep02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/Season_01.Episode_02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/Season_01/Episode_02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/Season_01/02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/S.I/Ep02.Episode_name.avi', 'Series Name', undef, 1, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/S.one/Ep twelve.Episode_name.avi', 'Series Name', undef, 1, 12, undef, undef, undef, 'Episode_name', 'avi'],
		],
	},
	{ # Movie IMDB Support
		# Perl > v5.10
		re => '^(?<movie>.*?)?(?:[\/\s._-]*(?<openb>\[)?(?<year>(?:19|20)\d{2})(?(<openb>)\]))?(?:[\/\s._-]*(?<openc>\[)?(?:(?:imdb|tt)[\s._-]*)*(?<imdb>\d{7})(?(<openc>)\]))(?:[\s._-]*(?<title>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(.*?)?(?:[\/\s._-]*\[?((?:19|20)\d{2})\]?)?(?:[\/\s._-]*\[?(?:(?:imdb|tt)[\s._-]*)*(\d{7})\]?)(?:[\s._-]*([^\/]+?))?$',
		keys_compat => [qw(movie year imdb title)],

		test_funcs => [0, 0, 0, 1], # DVD TV Episode Movie
		test_keys => [qw(filename movie guess-movie year imdb title ext)],
		test_files => [
			['Movie Name [1996] [imdb 1234567].mkv', 'Movie Name', undef, 1996, 1234567, undef, 'mkv'],
			['Movie Name [1996] [imdb tt1234567].mkv', 'Movie Name', undef, 1996, 1234567, undef, 'mkv'],
			['Movie Name [1996] [1234567].avi', 'Movie Name', undef, 1996, 1234567, undef, 'avi'],
			['Movie Name [1996] [tt1234567] foo.avi', 'Movie Name', undef, 1996, 1234567, 'foo', 'avi'],
			['Movie Name [1996]/tt1234567-foo.avi', 'Movie Name', undef, 1996, 1234567, 'foo', 'avi'],
			['Movie/Name/tt1234567_foo.avi', 'Name', 'Movie Name', undef, 1234567, 'foo', 'avi'],
			['Movie Name.[tt0096657] bar.avi', 'Movie Name', undef, undef, '0096657', 'bar', 'avi'],
			['Movie Name.tt0096657-foo.avi', 'Movie Name', undef, undef, '0096657', 'foo', 'avi'],
			['Movie.Name.tt0096657foo.avi', 'Movie.Name', undef, undef, '0096657', 'foo', 'avi'],
			['Movie Name.tt0096657_foo.avi', 'Movie Name', undef, undef, '0096657', 'foo', 'avi'],
			['Movie Name.tt0096657.avi', 'Movie Name', undef, undef, '0096657', undef, 'avi'],
			['Movie Name.[0096657].avi', 'Movie Name', undef, undef, '0096657', undef, 'avi'],
			['imdb-tt0096657.avi', undef, undef, undef, '0096657', undef, 'avi'],
			['tt0096657.mov', undef, undef, undef, '0096657', undef, 'mov'],
			['tt0096857', undef, undef, undef, '0096857', undef, undef],
			['1234576', undef, undef, undef, '1234576', undef, undef],
		],
		#warning => 'Found year instead of season+episode',
	},
	{ # Movie + Year Support
		# Perl > v5.10
		re => '^(?:(?<movie>.*?)[\/\s._-]*)?(?<openb>\[\(?)?(?<year>(?:19|20)\d{2})(?(<openb>)\)?\])(?:[\s._-]*(?<title>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]*)?\[?\(?((?:19|20)\d{2})\)?\]?(?:[\s._-]*([^\/]+?))?$',
		keys_compat => [qw(movie year title)],

		test_funcs => [0, 0, 0, 1], # DVD TV Episode Movie
		test_keys => [qw(filename movie year title ext)],
		test_files => [
			['Movie (1988).avi', 'Movie', 1988, undef, 'avi'],
			['Movie.[1988].avi', 'Movie', 1988, undef, 'avi'],
			['Movie.2000.title.avi', 'Movie', 2000, 'title', 'avi'],
			['Movie/2009.title.avi', 'Movie', 2009, 'title', 'avi'],
		],
		#warning => 'Found year instead of season+episode',
	},
	{ # TV Show Support - see
		# Perl > v5.10
		re => '^(?:(?<name>.*?)[\/\s._-]*)?(?<season>\d{1,2}?)(?<episode>\d{2})(?:[^0-9][\s._-]*(?<epname>.+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]*)?(\d{1,2}?)(\d{2})(?:[^0-9][\s._-]*(.+?))?$',
		keys_compat => [qw(name season episode epname)],

		test_funcs => [0, 1, 1, 0], # DVD TV Episode Movie
		test_keys => [qw(filename name season episode epname ext)],
		test_files => [
			['SN102.Episode_name.avi', 'SN', 1, 2, 'Episode_name', 'avi'],
			['Series Name.102.Episode_name.avi', 'Series Name', 1, 2, 'Episode_name', 'avi'],
			['Series Name/102.Episode_name.avi', 'Series Name', 1, 2, 'Episode_name', 'avi'],
		],
	},
	{ # TV Show Support - sxee
		# Perl > v5.10
		re => '^(?:(?<name>.*?)[\/\s._-]*)?(?<openb>\[)?(?<season>\d{1,2})[x\/](?<episode>\d{1,2})(?:-(?:\k<season>x)?(?<endep>\d{1,2}))?(?(<openb>)\])(?:[\s._-]*(?<epname>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]*)?\[?(\d{1,2})[x\/](\d{1,2})(?:-(?:\d{1,2}x)?(\d{1,2}))?\]?(?:[\s._-]*([^\/]+?))?$',
		keys_compat => [qw(name season episode endep epname)],

		test_funcs => [0, 1, 1, 0], # DVD TV Episode Movie
		test_keys => [qw(filename name season episode endep epname ext)],
		test_files => [
			['Series Name.1x02.Episode_name.avi', 'Series Name', 1, 2, undef, 'Episode_name', 'avi'],
			['Series Name/1x02.Episode_name.avi', 'Series Name', 1, 2, undef, 'Episode_name', 'avi'],
			['Series Name.[1x02].Episode_name.avi', 'Series Name', 1, 2, undef, 'Episode_name', 'avi'],
			['Series Name.1x02-03.Episode_name.avi', 'Series Name', 1, 2, 3, 'Episode_name', 'avi'],
			['Series Name.1x02-1x03.Episode_name.avi', 'Series Name', 1, 2, 3, 'Episode_name', 'avi'],
		],
	},
	{ # TV Show Support - season only
		# Perl > v5.10
		re => '^(?:(?<name>.*?)[\/\s._-]+)?(?:s|se|season|series)[\s._]?(?<season>\d{1,2})(?:[\/\s._-]*(?<epname>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]+)?(?:s|se|season|series)[\s._]?(\d{1,2})(?:[\/\s._-]*([^\/]+?))?$',
		keys_compat => [qw(name season epname)],

		test_funcs => [0, 0, 0, 0], # DVD TV Episode Movie
		test_keys => [qw(filename name season epname ext)],
		test_files => [
			['Series Name.s1.Episode_name.avi', 'Series Name', 1, 'Episode_name', 'avi'],
			['Series Name.s01.Episode_name.avi', 'Series Name', 1, 'Episode_name', 'avi'],
			['Series Name/se01.Episode_name.avi', 'Series Name', 1, 'Episode_name', 'avi'],
			['Series Name.season_1.Episode_name.avi', 'Series Name', 1, 'Episode_name', 'avi'],
			['Series Name/season_1/Episode_name.avi', 'Series Name', 1, 'Episode_name', 'avi'],
			['Series Name/season ten/Episode_name.avi', 'Series Name', 10, 'Episode_name', 'avi'],
		],
	},
	{ # TV Show Support - episode only
		# Perl > v5.10
		re => '^(?:(?<name>.*?)[\/\s._-]*)?(?:(?:e|ep|episode)[\s._]?)?(?<episode>\d{1,2})(?:-(?:e|ep)?(?<endep>\d{1,2}))?(?:(?:p|part)(?<part>\d+))?(?<subep>[a-z])?(?:[\/\s._-]*(?<epname>[^\/]+?))?$',

		# Perl < v5.10
		re_compat => '^(?:(.*?)[\/\s._-]*)?(?:(?:e|ep|episode)[\s._]?)?(\d{1,2})(?:-(?:e|ep)?(\d{1,2}))?(?:(?:p|part)(\d+))?([a-z])?(?:[\/\s._-]*([^\/]+?))?$',
		keys_compat => [qw(name episode endep part subep epname)],

		test_funcs => [0, 0, 1, 0], # DVD TV Episode Movie
		test_keys => [qw(filename name episode endep part subep epname ext)],
		test_files => [
			['Series Name.Episode_02.Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/Episode_02.Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/Ep02.Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['E02.Episode_name.avi', undef, 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.E02.Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.02.Episode_name.avi', 'Series Nam', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/E02.Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/02.Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/E02/Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name/02/Episode_name.avi', 'Series Name', 2, undef, undef, undef, 'Episode_name', 'avi'],
			['Series Name.E02a.Episode_name.avi', 'Series Name', 2, undef, undef, 'a', 'Episode_name', 'avi'],
			['Series Name.E02p3.Episode_name.avi', 'Series Name', 2, undef, 3, undef, 'Episode_name', 'avi'],
			['Series Name.E02-03.Episode_name.avi', 'Series Name', 2, 3, undef, undef, 'Episode_name', 'avi'],
			['Series Name.E02-E03.Episode_name.avi', 'Series Name', 2, 3, undef, undef, 'Episode_name', 'avi'],
		],
	},
	{ # Default Movie Support
		# Perl > v5.10
		re => '^(?<movie>.*)$',

		# Perl < v5.10
		re_compat => '^(.*)$',
		keys_compat => [qw(movie)],

		test_funcs => [0, 0, 0, 1], # DVD TV Episode Movie
		test_keys => [qw(filename movie ext)],
		test_files => [
			['Movie.mov', 'Movie', 'mov'],
		],
		#warning => 'Found year instead of season+episode',
	},
);

###############################################################################
sub new {
	my $self = bless {};
	# Read default values
	for my $key (qw(file name season episode part options)) {
		last unless defined $_[0];
		if (ref $_[0]) {
			# Use a hashref for values
			while (my ($key, $value) = each %{$_[0]}) {
				$self->{$key} = $value;
			}
		} else {
			$self->{$key} = shift;
		}
	}
	# Seed endep/subep from passed in episode
	if (defined $self->{episode}) {
		$self->{endep} = $1 if $self->{episode} =~ s/-(\d+)//i;
		$self->{subep} = $1 if $self->{episode} =~ s/([a-z])$//i;
	}
	&debug(5, "VideoFilename: $self->{file}\n");

	# Start parsing file
	my $file = $self->{file};
	$self->{dir} = $1 if $file =~ m|^(.*/)|;
	$self->{filename} = $1 if $file;
	$self->{ext} = lc $1 if $file =~ s/\.([0-9a-z]+)$//i;

	# Translate appropriate roman/english numbers to numerals
	my $prefix = '(?:d|dvd|disc|disk|s|se|season|e|ep|episode)[\s._-]+';
	my $end = '(?:day|part)[\s._-]+';
	$file = &_allroman2int($file, $prefix, $end);
	$file = &_allnum2int($file, $prefix, $end);

	# Strip out any irrelevant numbers which screw up parsing
	$file =~ s/480p//;
	$file =~ s/720p//;
	$file =~ s/1080p//;
	$file =~ s/x264//;
	$file =~ s/x265//;

	# Run pre-processed filename through list of patterns
	for my $pat (@filePatterns) {
		if ($] >= 5.010000) {
			if ($file =~ /$pat->{re}/i) {
				&warning($pat->{warning}) if defined $pat->{warning};
				&debug(3, "PARSEINFO: $pat->{re}\n");
				$self->{regex} = $pat->{re};
				while (my ($key, $data) = each %-) {
					$self->{$key} = $data->[0] if defined $data->[0] && !defined $self->{$key};
				}
				last;
			}
		} else { # No named groups in regexes
			my @matches;
			if (@matches = ($file =~ /$pat->{re_compat}/i)) {
				#print "MACTHES: ".join(',', @matches)."\n";
				&warning($pat->{warning}) if defined $pat->{warning};
				&debug(3, "PARSEINFO: $pat->{re_compat}\n");
				$self->{regex} = $pat->{re_compat};
				my $count = 0;
				foreach my $key (@{$pat->{keys_compat}}) {
					$self->{$key} = $matches[$count] unless defined $self->{$key};
					$count++;
				}
				last;
			}
		}
	}

	# Perhaps a movie is really a name with default season or episode
	if ((defined $self->{name} || defined $self->{season} || defined $self->{episode}) && defined $self->{movie}) {
		$self->{name} = $self->{movie} unless defined $self->{name};
		delete $self->{movie};
	}

	# Process Series/Movie
	for my $key (qw(name movie epname title)) {
		if (defined $self->{$key}) {
			if ($self->{$key} =~ /^.*\/(.*?)$/) {
				# Get rid of any directory parts
				$self->{"guess-$key"} = $self->{$key};
				# Keep the original name without '/' just in case the name contains a subdir
				$self->{$key} = $1;
				$self->{"guess-$key"} =~ s/[\/\s._-]+/ /;
			}
			$self->{$key} =~ s/[$self->{spaces}]+/ /g if defined $self->{spaces};
			$self->{$key} =~ s/^\s*(.+?)\s*$/$1/;	# Remove leading/trailing separators
		}
	}

	# Guess part from epname
	if (defined $self->{epname} && !defined $self->{part}) {
		my $rmpart = 'Episode|Part|PT';			 	# Remove "Part #" from episode name
		my $epname = &_allnum2int($self->{epname});	# Make letters into integers
		if ($epname =~ /(?:$rmpart) (\d+)/i
			|| $epname =~ /(\d+)\s*(?:of|-)\s*\d+/i
			|| $epname =~ /^(\d+)/
			|| $epname =~ /[\s._-](\d+)$/
		) {
			$self->{part} = $1;
		}
	}

	# Cosmetics
	for my $key (qw(dvd season episode endep part)) {
		$self->{$key} =~ s/^0+// if defined $self->{$key};
	}
	$self->{endep} = undef if $self->{endep} == $self->{episode};

	# Convenience for some developpers
	if (defined $self->{season}) {
		$self->{seasonepisode} = sprintf("S%02dE%02d", $self->{season}, $self->{episode});
	} elsif (defined $self->{dvd}) {
		$self->{seasonepisode} = sprintf("D%02dE%02.1f", $self->{dvd}, $self->{episode});
	}

	&debug(2, '', VideoFilename=>$self);
	return $self;
}

###############################################################################
sub _num2int {
	my $str = shift;
	my ($n, $c, $sum) = (0, 0, 0);
	while ($str) {
		$str =~ s/^[\s,]+//;
		debug(3, "STR=$str NUM=$n\n");

		if ($str =~ s/^(zero|and|&)//i)	 	{ next;
		} elsif ($str =~ s/^one//i)		 	{ $n += 1;
		} elsif ($str =~ s/^tw(o|en)//i)	{ $n += 2;
		} elsif ($str =~ s/^th(ree|ir)//i)	{ $n += 3;
		} elsif ($str =~ s/^four//i)		{ $n += 4;
		} elsif ($str =~ s/^fi(ve|f)//i)	{ $n += 5;
		} elsif ($str =~ s/^six//i)		 	{ $n += 6;
		} elsif ($str =~ s/^seven//i)		{ $n += 7;
		} elsif ($str =~ s/^eight//i)		{ $n += 8;
		} elsif ($str =~ s/^nine//i)		{ $n += 9;
		} elsif ($str =~ s/^(t|te|e)en//i)	{ $n += 10;
		} elsif ($str =~ s/^eleven//i)		{ $n += 11;
		} elsif ($str =~ s/^twelve//i)		{ $n += 12;
		} elsif ($str =~ s/^t?y//i)			{ $n *= 10;
		} elsif ($str =~ s/^hundred//i)		{ $c += $n * 100; $n = 0;
		} elsif ($str =~ s/^thousand//i)	{ $sum += ($c+$n) * 1000; ($c,$n) = (0,0);
		} elsif ($str =~ s/^million//i)		{ $sum += ($c+$n) * 1000000; ($c,$n) = (0,0);
		} elsif ($str =~ s/^billion//i)		{ $sum += ($c+$n) * 1000000000;	($c,$n) = (0,0);
		} elsif ($str =~ s/^trillion//i)	{ $sum += ($c+$n) * 1000000000000; ($c,$n) = (0,0);
		}
	}
	$sum += ($c+$n);
	debug(2, "STR=$str SUM=$sum\n");
	return $sum;
}
sub _allnum2int {
	my ($str, $prefix, $end) = @_;

	my $single = 'zero|one|two|three|five|(?:twen|thir|four|fif|six|seven|nine)(?:|teen|ty)|eight(?:|een|y)|ten|eleven|twelve';
	my $mult = 'hundred|thousand|(?:m|b|tr)illion';
	my $regex = "((?:(?:$single|$mult)(?:$single|$mult|\s|,|and|&)+)?(?:$single|$mult))";

	if ($] >= 5.010000) {
		$str =~ s/$prefix\K\b$regex\b/&_num2int($1)/egis;
		$str =~ s/$end\K\b$regex$/&_num2int($1)/egis if defined $end;
	} else {
		$str =~ s/($prefix)\b$regex\b/"$1".&_num2int($2)/egis;
		$str =~ s/($end)\b$regex$/"$1".&_num2int($2)/egis if defined $end;
	}

	return $str;
}
sub _allroman2int {
	my ($str, $prefix, $end) = @_;

	my $roman = '[MC]*[DC]*[CX]*[LX]*[XI]*[VI]*';
	if ($] >= 5.010000) {
		$str =~ s/\b$prefix\K($roman)\b/roman2int($1)/egi;
		$str =~ s/\b$end\K($roman)$/roman2int($1)/egi if defined $end;
	} else {
		$str =~ s/\b($prefix)($roman)\b/"$1".roman2int($2)/egi;
		$str =~ s/\b($end)($roman)$/"$1".roman2int($2)/egi if defined $end;
	}
	return $str;
}

###############################################################################
sub isDVDshow {
	my ($self) = @_;
	return defined $self->{dvd} && defined $self->{episode};
}

###############################################################################
sub isTVshow {
	my ($self) = @_;
	return defined $self->{season} && defined $self->{episode};
}

###############################################################################
sub isEpisode {
	my ($self) = @_;
	return defined $self->{episode};
}

###############################################################################
sub isMovie {
	my ($self) = @_;
	return defined $self->{movie} || defined $self->{imdb};
}

###############################################################################
sub testVideoFilename {
	my @funcs = qw(isDVDshow isTVshow isEpisode isMovie);
	for my $pat (@filePatterns) {
		for my $test (@{$pat->{test_files}}) {
			my $file = new($test->[0]);
			# Make the correct rule fired
			if ($file->{regex} ne $pat->{re}) {
				print RED "PATT RE: $pat->{re}\nFILE RE: $file->{regex}\n";
				print RED "FAILED: $file->{file} (wrong rule)\n";
				print Dumper($file); exit;
			}
			# Make sure all the attributes were correctly parsed
			my $keys = $pat->{test_keys};
			for my $i (1..8) {
				my $attr = $file->{$keys->[$i]};
				my $value = $test->[$i];
				if ($attr ne $value) {
					print RED "'$attr' ne '$value'\nFAILED: $file->{file}\n";
					print Dumper($file); exit;
				}
				&verbose(1, "'$attr' eq '$value'\n");
			}
			# Make sure all the isXXXX() functions work properly
			for my $i (0..$#funcs) {
				unless (eval "\$file->$funcs[$i]()" == $pat->{test_funcs}->[$i]) {
					print RED "\$file->$funcs[$i]() != $pat->{test_funcs}->[$i]\nFAILED: $file->{file}\n";
					print Dumper($file); exit;
				}
			}
			print GREEN "PASSED: $file->{file}\n";
		}
	}
}

###############################################################################
__END__

=head1 NAME

Video::Filename - Parse filenames for information about the video

=head1 SYNOPSIS

  use Video::Filename;

  my $file = Video::Filename::new($filename, [$name, [$season, [$episode]]]);
  my $file = Video::Filename::new($filename, {
                                     name => 'series name',
                                     season => 4,
                                     episode => 5,
                                     spaces => '\s._-',
                                 } );
  # TV or DVD Episode
  $file->{regex}
  $file->{dir}
  $file->{file}
  $file->{name}
  $file->{dvd}
  $file->{season}
  $file->{episode}
  $file->{endep}
  $file->{subep}
  $file->{part}
  $file->{epname}
  $file->{ext}

  # Movie
  $file->{movie}
  $file->{year}
  $file->{imdb}
  $file->{title}

  $file->isDVDshow();
  $file->isTVshow();
  $file->isEpisode();
  $file->isMovie();

  $file->testVideoFilename();

=head1 DESCRIPTION

Video::Filename is used to parse information line name/season/episode and such
from a video filename. It also does a reasonable job at distinguishing a movie
from a tv episode.

=over 4

=item $file = Video::Filename::new(FILENAME, [NAME, [SEASON, [EPISODE]]]);

Parse C<FILENAME> and return a Video::Filename object containing the data. If
you specify C<NAME>, C<SEASON>, and/or C<EPISODE> it will override what is
parsed from C<FILENAME>.

Alternatively, arguments can be passed in a hashref.  This also allows the user
to specify the option of specifying characters which are replaced with spaces
in the parsed 'name', 'epname', 'movie', and 'title' fields.

  my $file = Video::Filename::new('This.is.a.name.s01e01.episode_title.avi', {
                                     season => 4,
                                     spaces => '\s._-',
                                 } );
  print Dumper($file);

  $file = bless( {
                  'epname' => 'episode title',
                  'name' => 'This is a name',
                  'file' => 'This.is.a.name.s01e01.episode_title.avi',
                  'spaces' => '._',
                  'seasonepisode' => 'S04E01',
                  'episode' => 1,
                  'ext' => 'avi',
                  'season' => 4
                }, 'Video::Filename' );

Notice that that the season was overridden in the call to new(), so it's "4"
instead of the "1" parsed from the file name.

=item isDVDshow();

Returns true if the object represents a DVD episode.

=item isTVshow();

Returns true if the object represents a TV episode.

=item isEpisode();

Returns true if the object represents an episode (TV or DVD).

=item isMovie();

Returns true if the object represents a Movie.

=item testVideoFilename();

Run a series of tests on the rules used to parse filenames. Basically a test
harness.

=back

=head1 COPYRIGHT

Copyright (c) 2008 by Behan Webster. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 AUTHOR

S<Behan Webster E<lt>behanw@websterwood.comE<gt>>

=cut

# vim: sw=4 ts=4
