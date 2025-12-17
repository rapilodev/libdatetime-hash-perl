package Datetime::Hash;

use strict;
use warnings;
require Exporter;
require XSLoader;
use feature 'state';

our @ISA = qw(Exporter);
our $VERSION = '1.0.0';

# Functions available for export
our @EXPORT_OK = qw(format_datetime format_legacy);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

XSLoader::load('Datetime::Hash', $VERSION);

# Internal mapping for the legacy schema (new -> old)
my %LEGACY_MAP = (
    'date'          => 'date',
    'date_name'     => 'date_name',
    'day'           => 'day',
    'dow_iso'       => 'day_of_week',
    'doy'           => 'day_of_year',
    'epoch'         => 'epoch',
    'hour'          => 'hour',
    'iso8601_basic' => 'iso8601_basic',
    'minute'        => 'minute',
    'month'         => 'month',
    'month_long'    => 'month_name',
    'month_short'   => 'month_short_name',
    'datetime'      => 'datetime',
    'rfc3339'       => 'datetime_utc',
    'rfc5545'       => 'ics',
    'rfc822'        => 'rfc822',
    'time'          => 'time',
    'time_hm'       => 'time_hm',
    'second'        => 'second',
    'weekday_long'  => 'weekday_name',
    'weekday_short' => 'weekday_short_name',
    'year'          => 'year',
);

sub format_legacy {
    my ($dt_str, $tz, $locale, $prefix) = @_;
    $prefix //= '';
    my $dt = Datetime::Hash::format_datetime($dt_str, $tz, $locale, '') or return;
    return {
        map {
            $prefix.$LEGACY_MAP{$_} => $dt->{$_}
        } keys %LEGACY_MAP
    };
}

sub format_datetime_cached {
    my ($dt, $tz, $locale) = @_;
    state $cache = {};
    state $queue = [];
    my $key = join "\0", map { $_ // '' } ($dt, $tz, $locale);
    return $cache->{$key} if exists $cache->{$key};
    $cache->{$key} = format_datetime($dt, $tz, $locale);
    delete $cache->{shift @$queue} if @$queue >= 10000;
    push @$queue, $key;
    return $cache->{$key};
}
1;