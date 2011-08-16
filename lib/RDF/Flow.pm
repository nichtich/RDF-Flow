use strict;
use warnings;
package RDF::Flow;
#ABSTRACT: RDF data flow pipeline

use RDF::Flow::Source;
use RDF::Flow::Util qw();
use RDF::Flow::Union;
use RDF::Flow::Cascade;
use RDF::Flow::Pipeline;
use RDF::Flow::Cached;

use base 'Exporter';
our @EXPORT = qw(rdflow);
our @EXPORT_OK = qw(
    rdflow rdflow_uri
    cached union cascade pipeline previous
    has_retrieved
);
our %EXPORT_TAGS = (util => [qw(rdflow rdflow_uri)]);

our $PREVIOUS = RDF::Flow::Source->new( sub { shift->{'rdflow.data'} } );

sub rdflow   { RDF::Flow::Source->new(@_) }
sub union    { RDF::Flow::Union->new( @_ ) }
sub cascade  { RDF::Flow::Cascade->new( @_ ) }
sub pipeline { RDF::Flow::Pipeline->new( @_ ) }
sub cached   { RDF::Flow::Cached->new( @_ ); }

sub previous { $RDF::Flow::PREVIOUS; }

sub rdflow_uri { RDF::Flow::Util::rdflow_uri( @_ ); }

1;

=head1 SYNOPSIS

    # define RDF sources (see RDF::Flow::Source)
    $src = rdflow( "mydata.ttl", name => "RDF file as source" );
    $src = rdflow( \&mysub, name => "code reference as source" );
    $src = rdflow( $model,  name => "RDF::Trine::Model as source" );

    # using a RDF::Trine::Model as source is equivalent to:
    $src = RDF::Flow->new( sub {
        my $env = shift;
        my $uri = RDF::Flow::uri( $env );
        return $model->bounded_description( RDF::Trine::iri( $uri ) );
    } );

    # retrieve RDF data
    $rdf = $src->retrieve( $uri );
    $rdf = $src->retrieve( $env ); # uri constructed from $env

    # code reference as source (more detailed example)
    $src = rdflow( sub {
        my $uri = RDF::Flow::uri( $env );
        my $model = RDF::Trine::Model->temporary_model;
        add_some_statements( $uri, $model );
        return $model;
    });

=head1 DESCRIPTION

RDF::Flow provides a simple framework on top of L<RDF::Trine> to define and
connect RDF sources in data flow pipes. The base class to define RDF sources is
L<RDF::Flow::Source>. Predefined sources exist to access RDF as LinkedData
(L<RDF::Flow::LinkedData>), to cache requests (L<RDF::Flow::Cache>), to combine
sources (L<RDF::Flow::Union>, L<RDF::Flow::Pipeline>, L<RDF::Flow::Cascade>),
and for testing (L<RDF::Flow::Dummy>).

=head1 FUNCTIONS

This module exports some functions on request or by default.

=head2 rdflow

Shortcut to create a new source with L<RDF::Flow::Source>. This is the only
function exported by default.

=head2 rdflow_uri ( $env | $uri )

Gets and/or sets the request URI. You can either provide either a request URI
as byte string, or an environment as hash reference.  The environment must be a
specific subset of a L<PSGI> environment with the following variables:

=over 4

=item rdflow.uri

A request URI as byte string. If this variable is provided, no other variables
are needed and the following variables will not modify this value.

=item psgi.url_scheme

A string C<http> (assumed if not set) or C<https>.

=item HTTP_HOST

The base URL of the host for constructing an URI. This or SERVER_NAME is
required unless rdflow.uri is set.

=item SERVER_NAME

Name of the host for construction an URI. Only used if HTTP_HOST is not set.

=item SERVER_PORT

Port of the host for constructing an URI. By default C<80> is used, but not
kept as part of an HTTP-URI due to URI normalization.

=item SCRIPT_NAME

Path for constructing an URI. Must start with C</> if given.

=item QUERY_STRING

Portion of the request URI that follows the ?, if any.

=item rdflow.ignorepath

If this variable is set, no query part is used when constructing an URI.

=back

The method reuses code from L<Plack::Request> by Tatsuhiko Miyagawa. Note that
the environment variable REQUEST_URI is not included. When this method
constructs a request URI from a given environment hash, it always sets the
variable C<rdflow.uri>, so it is always guaranteed to be set after calling.
However it may be the empty string, if an environment without HTTP_HOST or
SERVER_NAME was provided.

=head2 cached

Shortcut for L<RDF::Flow::Cached>-E<gt>new.

=head2 cascade

Shortcut for L<RDF::Flow::Cascade>-E<gt>new.

=head2 pipeline

Shortcut for L<RDF::Flow::Pipeline>-E<gt>new.

=head2 previous

A source that always returns C<rdflow.data> without modification.

=head2 union

Shortcut for L<RDF::Flow::Union>-E<gt>new.

=head2 LOGGING

RDF::Flow uses L<Log::Contextual> for logging. By default no logging messages
are created, unless you enable a logger.

To simply see what's going on, enable:

    use Log::Contextual::SimpleLogger;
    use Log::Contextual qw( :log ),
       -logger => Log::Contextual::SimpleLogger->new({ levels => [qw(trace)]});

=head2 LIMITATIONS

The current version of this module does not check for circular references.
Another environment variable such as C<rdflow.depth> or C<rdflow.stack> may
help.

=head2 SEE ALSO

There are some CPAN modules for general data flow processing, such as L<Flow>
and L<DataFlow>. As RDF::Flow is inspired by L<PSGI>, you should also have a
look at the PSGI toolkit L<Plack>. RDF-related Perl modules are collected at
L<http://www.perlrdf.org/>.

The presentation "RDF Data Pipelines for Semantic Data Federation", includes
more RDF Pipelining research references: L<http://dbooth.org/2011/pipeline/>
(not directly related to this module).

=cut
