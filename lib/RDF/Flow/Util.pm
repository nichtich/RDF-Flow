use strict;
use warnings;
package RDF::Flow::Util;
#ABSTRACT: Helper functions to create your own sources

use RDF::Flow;
use Carp qw(croak);

use parent 'Exporter';
our @EXPORT = qw(sourcelist_args);

sub sourcelist_args {
    my ($inputs, $args) = ([],{});
    while ( @_ ) {
        my $s = shift @_;
        if ( ref $s ) {
            push @$inputs, map { RDF::Flow::rdflow($_) } $s;
        } elsif ( defined $s ) {
            $args->{$s} = shift @_;
        } else {
            croak 'undefined parameter';
        }
    }
    return ($inputs, $args);
}

1;

=head1 FUNCTIONS

=head2 sourcelist_args ( @_ )

Parses a list of inputs (code or other references) mixed with key-value pairs
and returns both separated in an array and and hash.

=cut
