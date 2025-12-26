use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Sortkeys=1;
use Test::More;
use Datetime::Hash qw(format_datetime format_legacy);

## 1. Verify XS Output (The source of the data)
subtest 'Internal XS Keys' => sub {
    my $dt = "2023-10-25 14:30:05";
    my $res = format_datetime($dt, "UTC", "en_US");
    ok($res->{datetime}, "Has 'datetime' key");
    ok($res->{datetime}, "Has 'datetime' key (needed for legacy)");
    is($res->{datetime}, "2023-10-25 14:30:05", "datetime_iso value is correct");
};

## 2. Verify Legacy Mapping
subtest 'format_legacy mapping' => sub {
    my $dt = "2023-10-25 14:30:05";
    my $res = format_legacy($dt, "Europe/Berlin", "de_DE");
    ok($res, "format_legacy returned a hash");
    is($res->{'datetime'}, "2023-10-25 14:30:05", "Legacy root key is correct");
    # Check a few mapped keys
    is($res->{month_name}, "Oktober", "Mapped month_long -> month_name");
    is($res->{time}, "14:30:05", "Mapped time_hm -> time");
};

## 3. Verify Prefixed Legacy
subtest 'Prefix support' => sub {
    my $dt = "2023-10-25 14:30:05";
    my $pfx = "evt_";
    my $res = format_legacy($dt, "UTC", "en_US", $pfx);
    warn Dumper($res);

    is($res->{evt_year}, "2023", "Prefixed year exists");
    is($res->{evt_month_name}, "October", "Prefixed mapped key exists");
};

done_testing();
