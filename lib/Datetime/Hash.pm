package Datetime::Hash;

use strict;
use warnings;
require Exporter;
require XSLoader;

our @ISA = qw(Exporter);
our $VERSION = '1.0.0';

# Functions available for export
our @EXPORT_OK = qw(format_datetime format_legacy);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

XSLoader::load('Datetime::Hash', $VERSION);

# Internal mapping for the legacy schema
my %LEGACY_MAP = (
    'dow_iso'       => 'day_of_week',
    'doy'           => 'day_of_year',
    'weekday_long'  => 'weekday_name',
    'weekday_short' => 'weekday_short_name',
    'month_long'    => 'month_name',
    'month_short'   => 'month_short_name',
    'date_name'     => 'date_name',
    'date'          => 'date',
    'datetime'      => 'datetime',
    'iso8601_basic' => 'iso8601_basic',
    'rfc3339'       => 'datetime_utc',
    'time_hm'       => 'time',
    'epoch'         => 'epoch',
    'day'           => 'day', 
    'month'         => 'month', 
    'year'          => 'year',
    'hour'          => 'hour', 
    'minute'        => 'minute', 
    'second'        => 'second',
    'rfc5545'       => 'ics', 
    'rfc822'        => 'rfc822',
);

sub format_legacy {
    my ($dt_str, $tz, $locale, $prefix) = @_;
    $prefix //= '';
    
    # Call the XS function (fully qualified to be safe)
    my $new_hash = Datetime::Hash::format_datetime($dt_str, $tz, $locale, $prefix);
    return undef unless $new_hash;

    my $legacy_hash = {};
    
    # Map to old keys
    while (my ($new_sfx, $old_sfx) = each %LEGACY_MAP) {
        my $new_key = $prefix . $new_sfx;
        my $old_key = $prefix . $old_sfx;
        $legacy_hash->{$old_key} = $new_hash->{$new_key} if exists $new_hash->{$new_key};
    }

    # Add the special legacy root key "YYYY-MM-DD HH:MM:SS"
    my $val = $new_hash->{$prefix . "datetime_iso"};
    if ($val) {
        $val =~ s/T/ /;
        $legacy_hash->{$prefix} = $val;
    }
    
    # Add time_name alias
    $legacy_hash->{$prefix . "time_name"} = $legacy_hash->{$prefix . "time"};

    return $legacy_hash;
}

1;