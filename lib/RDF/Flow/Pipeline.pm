use strict;
use warnings;
package RDF::Flow::Pipeline;
#ABSTRACT: Pipelines multiple sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Flow::Source';
use RDF::Flow::Source qw(:util);

sub new {
    my $class = shift;
    my ($inputs, $args) = sourcelist_args( @_ );

    my $self = bless {
        inputs => $inputs,
        name   => ($args->{name} || 'anonymous pipeline'),
    }, $class;

    $self->match( $args->{match} );

    return $self;
}

sub retrieve_rdf {
    my ($self, $env) = @_;

    foreach my $src ( $self->inputs ) {
        my $rdf = $src->retrieve( $env );
        $env->{'rdflow.data'} = $rdf;
        last if empty_rdf( $rdf );
    }

    $env->{'rdflow.data'};
}

# experimental
sub _graphviz_edgeattr {
    my ($self,$n) = @_;
    return (label => sprintf("%d.",$n));
}

1;

=head1 DESCRIPTION

This L<RDF::Flow::Source> wraps other sources as pipeline. Sources are
retrieved one after another. The response of each source is saved in the
environment variable C<rdflow.data> which is accesible to the next source.
The pipeline is aborted without error if C<rdflow.data> has not content, so
you can also use a pipleline as conditional branch. To pipe one source after
another, you can also use a source's C<pipe_to> method.

The module L<RDF::Flow> exports functions C<pipeline> and C<previous> on
request.

=head1 SYNOPSIS

    use RDF::Flow::Pipeline;

    $src = pipeline( @sources );                  # shortcut

    $src = RDF::Flow::Pipeline->new( @sources );  # explicit

    $rdf = $src->retrieve( $env );
    $rdf == $env->{'rdflow.data'};                # always true

    # pipeline as conditional: if $s1 has content then union of $s1 and $s2
    use RDF::Flow qw(pipeline union previous);
    pipeline( $s1, union( previous, $s2 ) );
    $s1->pipe_to( union( previous, $s2) );        # equivalent

=head1 SEE ALSO

L<RDF::Flow::Cascade>, L<RDF::Flow::Union>

=cut
