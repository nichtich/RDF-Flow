use strict;
use warnings;
package RDF::Flow::Pipeline;
#ABSTRACT: Pipelines multiple sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Flow::Source';
use RDF::Flow::Util;
use Carp 'croak';
our @CARP_NOT = qw(RDF::Flow::Util);
our @EXPORT = qw(pipeline previous);

sub new {
    my $class = shift;
    my ($inputs, $args) = sourcelist_args( @_ );

    bless {
        inputs => $inputs,
        name   => ($args->{name} || 'anonymous pipeline'),
    }, $class;
}

sub pipeline { 
    RDF::Flow::Pipeline->new(@_) 
}

sub _retrieve_rdf {
    my ($self, $env) = @_;

    foreach my $src ( $self->inputs ) {
        my $rdf = $src->retrieve( $env );
        $env->{'rdflow.data'} = $rdf;
        last unless is_rdf_data( $rdf );
    }

    $env->{'rdflow.data'};
}

sub previous { 
    $RDF::Flow::PREVIOUS; 
}

sub _graphviz_edgeattr {
	my ($self,$n) = @_;
	return (label => sprintf("%d.",$n));
}

1;

__END__

=head1 DESCRIPTION

This L<RDF::Flow> wraps other sources as pipeline. Sources are
retrieved one after another. The response of each source is saved in the
environment variable 'rdflow.data' which is accesible to the next source.
The pipeline is aborted without error if rdflow.data has not content
(see RDF::Flow::has_content), so you can also use a pipleline as
conditional branch. To pipe one source after another, you can also use the
'pipe_to' method of RDF::Flow.

=head1 SYNOPSIS

    use RDF::Flow::Pipeline;

    $src = pipeline( @sources );                    # shortcut
    $src = RDF::Flow::Pipeline->new( @sources );  # explicit
    $rdf = $src->retrieve( $env );
    $rdf == $env->{'rdflow.data'};               # always true

    # pipeline as conditional: if $s1 has content then union of $1 and $2
    use RDF::Flow::Union;
    pipeline( $s1, union( previous, $s2 ) );
    $s1->pipe_to( union( previous, $s2) );          # equivalent

=head1 EXPORTED FUNCTIONS

=head2 pipeline

Shortcut for RDF::Flow::Pipeline->new.

=head2 previous

Returns a source that always returns rdflow.data without modification.

=head2 SEE ALSO

L<RDF::Flow::Cascade>, L<RDF::Flow::Union>

=cut
