use strict;
use warnings;
package RDF::Flow::Union;
#ABSTRACT: Returns the union of multiple sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use RDF::Flow::Util;
use Carp;
our @CARP_NOT = qw(RDF::Flow::Util);

use parent 'RDF::Flow::Source';

sub new {
    my $class = shift;
    my ($inputs, $args) = sourcelist_args( @_ );

    bless {
        inputs => $inputs,
        name   => ($args->{name} || 'anonymous union'),
    }, $class;
}

sub about {
    my $self = shift;
    $self->name($self) . ' with ' . $self->size . ' inputs';
}

sub retrieve_rdf { # TODO: try/catch errors?
    my ($self, $env) = @_;
    my $result;

    if ( $self->size == 1 ) {
        $result = $self->[0]->retrieve( $env );
    } elsif( $self->size > 1 ) {
        $result = RDF::Trine::Model->new;
        foreach my $src ( $self->inputs ) { # TODO: parallel processing?
            my $rdf = $src->retrieve( $env );
            next unless defined $rdf;
            $rdf = $rdf->as_stream unless $rdf->isa('RDF::Trine::Iterator');
            iterator_to_model( $rdf, $result );
        }
    }

    return $result;
}

# experimental
sub _graphviz_edgeattr {
    my ($self,$n) = @_;
    return ();
}

1;

=head1 DESCRIPTION

This L<RDF::Flow> returns the union of responses of a set of input sources.

=head1 SYNOPSIS

    use RDF::Flow qw(union);
    $src = union( @sources );                 # shortcut

    use RDF::Flow::Union;
    $src = RDF::Flow::Union->new( @sources ); # explicit

    $rdf = $src->retrieve( $env );

=head2 SEE ALSO

L<RDF::Flow::Cascade>, L<RDF::Flow::Pipeline>

=cut
