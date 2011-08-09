use strict;
use warnings;
package RDF::Flow::Util;
#ABSTRACT: Helper functions to create your own sources

use Carp qw(croak);

use RDF::Trine::Model;
use RDF::Flow::Source;
use URI;
use URI::Escape;

use parent 'Exporter';
our @EXPORT = qw(sourcelist_args iterator_to_model is_rdf_data rdflow_uri);

sub sourcelist_args {
    my ($inputs, $args) = ([],{});
    while ( @_ ) {
        my $s = shift @_;
        if ( ref $s ) {
            push @$inputs, map { RDF::Flow::Source->new($_) } $s;
        } elsif ( defined $s ) {
            $args->{$s} = shift @_;
        } else {
            croak 'undefined parameter';
        }
    }
    return ($inputs, $args);
}

sub iterator_to_model {
    my $iterator = shift;
    my $model = shift || RDF::Trine::Model->new;

    $model->begin_bulk_ops;
    while (my $st = $iterator->next) {
        $model->add_statement( $st );
    }
    $model->end_bulk_ops;

    $model;
}

sub is_rdf_data {
    my $rdf = shift;
    return unless blessed $rdf;
    return ($rdf->isa('RDF::Trine::Model') and $rdf->size > 0) ||
           ($rdf->isa('RDF::Trine::Iterator') and $rdf->peek);
}

sub rdflow_uri {
    my $env = shift;
    return ($env || '') unless ref $env; # plain scalar or undef

    return $env->{'rdflow.uri'} if defined $env->{'rdflow.uri'};

    # a few lines of code from Plack::Request, so we don't require all of Plack
    my $base = ($env->{'psgi.url_scheme'} || "http") .
        "://" . ($env->{HTTP_HOST} || (($env->{SERVER_NAME} || "") .
        ":" . ($env->{SERVER_PORT} || 80))) . ($env->{SCRIPT_NAME} || '/');
    $base = URI->new($base)->canonical;

    my $path_escape_class = '^A-Za-z0-9\-\._~/';

    my $path = URI::Escape::uri_escape( $env->{PATH_INFO} || '', $path_escape_class );

    $path .= '?' . $env->{QUERY_STRING} if !$env->{'rdflow.ignorepath'} &&
        defined $env->{QUERY_STRING} && $env->{QUERY_STRING} ne '';

    $base =~ s!/$!! if $path =~ m!^/!;

    $env->{'rdflow.uri'} = URI->new( $base . $path )->canonical->as_string;

    $env->{'rdflow.uri'} =~ s/^https?:\/\/\/$//;
    $env->{'rdflow.uri'};
}


1;

=head1 DESCRIPTION

This module exports some method to be used in source modules.

=head1 FUNCTIONS

=head2 rdflow_uri ( $env | $uri )

Prepares and returns a request URI, as given by an evironment hash or by an
existing URI. Sets C<rdflow.uri> if an environment has been given. URI
construction is based on code from L<Plack>. It used the environment variables
C<psgi.url_scheme>, C<HTTP_HOST> or C<SERVER_NAME>, C<SERVER_PORT>,
C<SCRIPT_NAME>, C<PATH_INFO>, C<QUERY_STRING>, and C<rdflow.ignorepath>.
See L<RDF::Flow> for documentation.

=head2 sourcelist_args ( @_ )

Parses a list of inputs (code or other references) mixed with key-value pairs
and returns both separated in an array and and hash.

=head2 iterator_to_model ( $iterator [, $model ] )

Adds all statements from a L<RDF::Trine::Iterator> to a (possibly new)
L<RDF::Trine::Model> model and returns the model.

=head2 is_rdf_data ( $rdf )

Checks whether the argument is a non-empty L<RDF::Trine::Model> or a
non-empty L<RDF::Trine::Iterator>.

=cut
