=head1 NAME

Datetime::Hash - Fast XS-based date formatting into hashes using ICU.

=head1 SYNOPSIS

    use Datetime::Hash qw(format_datetime format_legacy);

    # Modern Schema
    my $hash = format_datetime("2025-12-17 13:15:00", "Europe/Berlin", "de_DE");

    # Legacy Schema (Compatible with 0.0.x)
    my $old = format_legacy("2025-12-17 13:15:00", "Europe/Berlin");

=head1 DESCRIPTION

Utilizes the ICU (International Components for Unicode) library to perform 
high-speed date formatting directly in C.

=head2 FUNCTIONS

=head3 format_datetime($str, $tz, $locale?, $prefix?)

Returns a hashref with the professional schema (e.g., C<display_name>, C<timestamp>).

=head3 format_legacy($str, $tz, $locale?, $prefix?)

Returns a hashref with the original schema (e.g., C<date_name>, C<epoch>).

=cut
