use strict;
use warnings;
package RDF::Flow::Dummy;
#ABSTRACT: Dummy source that always returns one trivial triple

use RDF::Trine qw(statement iri);

use parent 'RDF::Flow::Source';
use RDF::Flow::Source qw(:util);

our $rdf_type      = iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
our $rdfs_Resource = iri('http://www.w3.org/2000/01/rdf-schema#Resource');

sub retrieve_rdf {
    my ($self, $env) = @_;
    my $uri = rdflow_uri( $env );

    my $rdf = RDF::Trine::Model->new;

    $rdf->add_statement( statement( iri($uri), $rdf_type, $rdfs_Resource ) )
        if $uri;

    return $rdf;
}

1;

=head2 DESCRIPTION

This L<RDF::Flow::Source> always returns a single triple such as

    <http://example.org/> rdf:type rdfs:Resource .

where C<http://example.org> is replaced by the request URI. No triple is added
if the request is broken by not providing a request URI. You can use this
module for testing and as boilerplate for you own sources.

=cut
