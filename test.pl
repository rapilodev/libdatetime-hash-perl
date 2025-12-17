use strict;
use warnings;
use lib 'blib/lib', 'blib/arch'; 
use Datetime::Hash qw(format_datetime);
use Data::Dumper;
$Data::Dumper::Sortkeys=1;

my $res;
for my $i (0..4000) {
	$res = format_datetime("2025-12-17 13:15:00", "Europe/Berlin", "de_DE", "");
}

if ($res) {
    print "Success!\n";
    print Dumper($res);
} else {
    print "Failed to parse or initialize ICU.\n";
}
