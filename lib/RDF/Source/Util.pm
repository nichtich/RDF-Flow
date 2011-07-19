use strict;
use warnings;
package RDF::Source::Util;
#ABSTRACT: Helper functions to create your own sources

use RDF::Source;
use Carp qw(croak);

use parent 'Exporter';
our @EXPORT = qw(sourcelist_args);

sub sourcelist_args {
    my ($sources, $args) = ([],{});
    while ( @_ ) {
        my $s = shift @_;
        if ( ref $s ) {
            push @$sources, map { RDF::Source::source($_) } $s;
        } elsif ( defined $s ) {
            $args->{$s} = shift @_;
        } else {
            croak 'undefined parameter';
        }
    }
    return ($sources, $args);
}

1;

=head1 FUNCTIONS

=head2 sourcelist_args ( @_ )

Parses a list of sources (code or other references) mixed with key-value pairs
and returns both separated in an array and and hash.

=cut
