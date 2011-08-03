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

sub new {
    my ($class, %args) = @_;

    my $url = $args{url} || undef;
    if ( $url ) {
        $url = sub { shift =~ $url }
            if reftype $url eq 'REGEXP';
        croak 'url parameter must be code or regexp'
            if reftype $url ne 'CODE';
    }

    bless {
        url  => $url,
        name => ($args{name} || 'anonymous LinkedData source'),
    }, $class;
}

sub _retrieve_rdf {
    my ($self, $env) = @_;
    my $uri = rdflow_uri( $env );
    my $url = $uri;

    if ( $self->{url} ) {
        $url = $self->{url}->( $uri );
        if ( not $url ) {
            log_trace { "URI did not match: $uri" };
            return;
        }
    }
    
    my $model = RDF::Trine::Model->new;

    try {
        RDF::Trine::Parser->parse_url_into_model( $url, $model );
        log_debug { "retrieved data from $url" };
    } catch {
        $self->source_error("failed to retrieve RDF from $url: $_", $env); 
    };

    return $model;
}

1;

__END__

=head1 CONFIGURATION

=over 4

=item name

Name of the source. Defaults to "anonymous LinkedData source".

=item url

Optional regular expression or code reference to match and/or map request URIs.

=cut
