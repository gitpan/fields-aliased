##==============================================================================
## fields::aliased::base - base class for objects made from fields::aliased
##==============================================================================
## Copyright 2004 Kevin Michael Vail
## This program is free software. It may be copied and/or redistributed under
## the same terms as Perl itself.
##==============================================================================
## $Id: base.pm,v 1.0 2004/09/28 02:57:31 kevin Exp $
##==============================================================================
require 5.006;

package ## this doesn't need indexing
	fields::aliased::base;
use strict;
use warnings;
our ($VERSION) = q$Revision: 1.0 $ =~ /^Revision:\s+(\S+)/ or $VERSION = "0.0";
require fields;
use Carp;

=head1 NAME

fields::aliased::base - base class for objects made from fields::aliased

=head1 DESCRIPTION

This module just defines the base class for objects created as a subclass of
L<fields::aliased>.

=head1 METHODS

=over 4

=item new

C<< I<$object> = I<$class>->new; >>

Creates a new object. See L<fields::aliased/new> for details.

=cut

my %initializers = (
	'$'		=>	sub { undef },
	'@'		=>	sub { [] },
	'%'		=>	sub { {} },
);

##==============================================================================
## new
##==============================================================================
sub new {
	no strict 'refs';
	my $class = shift;
	
	unless (defined %{"$class\::FIELDS"}) {
		croak "$class doesn't appear to have any defined fields";
	}
	
	my $self = fields::new($class);
	my $fields = \%{"$class\::FIELDS"};
	
	foreach my $field (keys %$fields) {
		my ($vartype) = unpack 'a1', fields::aliased::field2varname($field);
		croak "field $field has invalid data type"
			unless exists $initializers{$vartype};
		
		$self->{$field} = $initializers{$vartype}->();
	}
	
	return $self;
}

=pod

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2004 Kevin Michael Vail

This program is free software.  It may be copied and/or redistributed under the
same terms as Perl itself.

=head1 AUTHOR

Kevin Michael Vail <F<kvail>@F<cpan>.F<org>>

=cut

1;

##==============================================================================
## $Log: base.pm,v $
## Revision 1.0  2004/09/28 02:57:31  kevin
## Initial revision
##==============================================================================
