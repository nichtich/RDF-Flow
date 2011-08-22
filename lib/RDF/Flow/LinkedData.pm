use strict;
use warnings;
package RDF::Flow::LinkedData;
#ABSTRACT: Retrieve RDF from a HTTP-URI

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Flow::Source';
use RDF::Flow::Util;

use Try::Tiny;
use RDF::Trine::Model;
use RDF::Trine::Parser;
use Scalar::Util qw(reftype);
use Carp;

sub name {
    shift->{name} || 'anonymous LinkedData source';
}

sub retrieve_rdf {
    my ($self, $env) = @_;
    my $url = rdflow_uri( $env );

    my $model = RDF::Trine::Model->new;

    try {
        die 'not an URL' unless $url =~ /^http[s]?:\/\//;
        RDF::Trine::Parser->parse_url_into_model( $url, $model );
        log_debug { "retrieved data from $url" };
    } catch {
        $self->trigger_error("failed to retrieve RDF from $url: $_", $env);
    };

    return $model;
}

1;

=head1 DESCRIPTION

This L<RDF::Flow::Source> fetches RDF data via HTTP. The request URI is used
as URL to get data from.

=head1 CONFIGURATION

The following configuration options from L<RDF::Flow::Source> are useful in
particular:

=over 4

=item name

Name of the source. Defaults to "anonymous LinkedData source".

=item match

Optional regular expression or code reference to match and/or map request URIs.

=back

=cut
