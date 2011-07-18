use strict;
use warnings;
package RDF::Source::Union;
#ABSTRACT: Returns the union of multiple sources

use Log::Contextual::WarnLogger;
use Log::Contextual qw(:log), -default_logger
    => Log::Contextual::WarnLogger->new({ env_prefix => __PACKAGE__ });

use parent 'RDF::Source';
our @EXPORT = qw(union);

sub new {
    my $class = shift;

    # TODO: support name => $name

    bless {
        sources => [ map { RDF::Source::source($_) } @_ ],
        name    => 'anonymous union'
    } , $class;
}

sub retrieve { # TODO: try/catch errors?
    my ($self, $env) = @_;
    my $result;

    log_trace {
        'retrieve from ' . sourcename($self) . ' with ' . $self->size . ' sources'
    };

    if ( $self->size == 1 ) {
        $result = $self->[0]->retrieve( $env );
    } elsif( $self->size > 1 ) {
        $result = RDF::Trine::Model->new;
        foreach my $src ( @{$self->{sources}} ) { # TODO: parallel processing?
            my $rdf = $src->retrieve( $env );
            next unless defined $rdf;
            $rdf = $rdf->as_stream unless $rdf->isa('RDF::Trine::Iterator');

            $result->begin_bulk_ops;
            while (my $st = $rdf->next) {
                $result->add_statement( $st );
            }
            $result->end_bulk_ops;
        }
    }

    $self->has_retrieved( $result );
}

sub union { RDF::Source::Union->new(@_) }

1;

__END__

=head1 DESCRIPTION

This L<RDF::Source> returns the union of responses of a set of sources.
It exports the function 'union' as constructor shortcut.

=head1 SYNOPSIS

    use RDF::Source::Union;

    $src = union(@sources);                     # shortcut
    $src = RDF::Source::Union->new( @sources ); # explicit
    $rdf = $src->retrieve( $env );

=head1 EXPORTED FUNCTIONS

=head2 union

Shortcut for RDF::Source::Union->new.

=head2 SEE ALSO

L<RDF::Source::Cascade>, L<RDF::Source::Pipeline>

=cut
