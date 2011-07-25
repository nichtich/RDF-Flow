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

use parent 'RDF::Flow';

our @EXPORT = qw(union);

sub new {
    my $class = shift;
    my ($inputs, $args) = sourcelist_args( @_ );

    bless {
        inputs => $inputs,
        name   => ($args->{name} || 'anonymous union'),
    }, $class;
}

sub union { 
    RDF::Flow::Union->new(@_) 
}

sub about {
    my $self = shift;
    $self->name($self) . ' with ' . $self->size . ' inputs';
}

sub _retrieve_rdf { # TODO: try/catch errors?
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

            $result->begin_bulk_ops;
            while (my $st = $rdf->next) {
                $result->add_statement( $st );
            }
            $result->end_bulk_ops;
        }
    }

    return $result;
}

sub _graphviz_edgeattr {
	my ($self,$n) = @_;
	return ();
}

1;

__END__

=head1 DESCRIPTION

This L<RDF::Flow> returns the union of responses of a set of input sources.
It exports the function 'union' as constructor shortcut.

=head1 SYNOPSIS

    use RDF::Flow::Union;

    $src = union(@sources);                     # shortcut
    $src = RDF::Flow::Union->new( @sources ); # explicit
    $rdf = $src->retrieve( $env );

=head1 EXPORTED FUNCTIONS

=head2 union

Shortcut for RDF::Flow::Union->new.

=head2 SEE ALSO

L<RDF::Flow::Cascade>, L<RDF::Flow::Pipeline>

=cut
