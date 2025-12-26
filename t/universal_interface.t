use strict;
use warnings;
use Test::More;
use Datetime::Hash qw(format_datetime);

# 1. Test Epoch Input (Numeric)
subtest 'Epoch Input' => sub {
    my $epoch = 1735210800; # 2024-12-26 12:00:00 UTC
    my $res = format_datetime($epoch, "UTC", "de_DE");
    
    ok($res, "Handled numeric epoch");
    is($res->{year}, 2024, "Correct year from epoch");
    is($res->{month}, 12, "Correct month from epoch");
    is($res->{day}, 26, "Correct day from epoch");
    is($res->{epoch}, $epoch, "Epoch value round-trip matches");
};

# 2. Test SQL-style String (The fallback parser)
subtest 'SQL String Input' => sub {
    my $sql_dt = "2025-10-25 14:30:05";
    my $res = format_datetime($sql_dt, "Europe/Berlin", "de_DE");
    
    ok($res, "Handled space-separated SQL string");
    is($res->{date}, "2025-10-25", "Date part correct");
    is($res->{time}, "14:30:05", "Time part correct");
    is($res->{date_name}, "25.10.2025", "German date_name format correct (DD.MM.YYYY)");
};

# 3. Test ISO 8601 with Zulu (Z) Offset
subtest 'ISO Offset (Z)' => sub {
    # 12:00 UTC should be 13:00 in Berlin (CET)
    my $iso = "2025-12-26T12:00:00Z"; 
    my $res = format_datetime($iso, "Europe/Berlin", "de_DE");
    
    is($res->{hour}, 13, "Offset 'Z' correctly shifted UTC to Berlin time");
    is($res->{rfc3339}, "2025-12-26T12:00:00Z", "RFC3339 stays in Zulu");
};

# 4. Test Locale Switching
subtest 'Locale Support' => sub {
    my $dt = "2025-12-26 12:00:00";
    
    my $de = format_datetime($dt, "UTC", "de_DE");
    my $us = format_datetime($dt, "UTC", "en_US");
    
    is($de->{weekday_long}, "Freitag", "German weekday");
    is($us->{weekday_long}, "Friday", "English weekday");
    
    # Check date_name differences
    is($de->{date_name}, "26.12.2025", "German date format (Dots)");
    # Note: en_US medium date usually uses commas or slashes depending on ICU version
    like($us->{date_name}, qr/Dec 26, 2025|12\/26\/2025/, "English date format");
};

# 5. Test Prefixing in XS
subtest 'XS Prefixing' => sub {
    my $res = format_datetime(1735210800, "UTC", "en_US", "start_");
    
    ok(exists $res->{start_year}, "Prefix 'start_' applied to year");
    ok(exists $res->{start_date_name}, "Prefix 'start_' applied to date_name");
    is($res->{start_year}, 2024, "Prefixed value is correct");
};

done_testing();

