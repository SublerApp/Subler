#!/usr/bin/perl

use Video::Filename;

my $filename = $ARGV[0];

my $file = Video::Filename::new($filename);

if ($file->isTVshow()) {
	print "tv" . "\n";
	print $file->{name} . "\n";
	print $file->{season} . "\n";
	print $file->{episode} . "\n";
} elsif ($file->isEpisode()) {
	print "tv" . "\n";
	print $file->{name} . "\n";
	print $file->{season} . "\n";
	print $file->{episode} . "\n";
	print $file->{part} . "\n";
} elsif ($file->isMovie()) {
	print "movie" . "\n";
	print $file->{movie} . "\n";
} else {
    print "unknown" . "\n";
}

exit;
