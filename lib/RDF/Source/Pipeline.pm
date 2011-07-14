use strict;
use warnings;
package RDF::Source::Pipeline;
#ABSTRACT: Pipelines multiple sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger 
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Source';
our @EXPORT = qw(pipeline previous);

sub new {
    my $class = shift;
	bless { 
        sources => [ map { RDF::Source::source($_) } @_ ],
        name    => 'anonymous pipeline'
    } , $class;
}

sub retrieve {
    my ($self, $env) = @_;

    log_trace { 'retrieve from ' . $self->name };

    foreach my $src ( @{$self->{sources}} ) {
        my $rdf = $src->retrieve( $env );
        $env->{'rdfsource.data'} = $rdf;
		last unless RDF::Source::has_content( $rdf );
    }

    log_trace { 
        my $rdf = $env->{'rdfsource.data'};
        $self->name . ' returned ' . (defined $rdf ? $rdf->size : 'no') . ' triples'
    };

    $env->{'rdfsource.data'};
}

sub pipeline { RDF::Source::Pipeline->new(@_) }

sub previous { $RDF::Source::PREVIOUS; }

1;

__END__

=head1 DESCRIPTION

This L<RDF::Source> wraps other sources as pipeline. Sources are 
retrieved one after another. The response of each source is saved in the
environment variable 'rdfsource.data' which is accesible to the next source.
The pipeline is aborted without error if rdfsource.data has not content
(see RDF::Source::has_content), so you can also use a pipleline as 
conditional branch. To pipe one source after another, you can also use the 
'pipe_to' method of RDF::Source.

=head1 SYNOPSIS

	use RDF::Source::Pipeline;

	$src = pipeline( @sources );                           # shortcut
    $src = RDF::Source::Pipeline->new( @sources );  # explicit
	$rdf = $src->retrieve( $env );
    $rdf == $env->{'rdfsource.data'};                       # always true

    # pipeline as conditional: if $s1 has content then union of $1 and $2
    use RDF::Source::Union;
    pipeline( $s1, union( previous, $s2 ) );
    $s1->pipe_to( union( previous, $s2) );    # equivalent 

=head1 EXPORTED FUNCTIONS

=over 4

=item pipeline

Constructor shortcut.

=item previous

Returns a source that always returns rdfsource.data without modification.

=head2 SEE ALSO

L<RDF::Source::Cascade>, L<RDF::Source::Union>

=cut
