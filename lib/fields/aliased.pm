##==============================================================================
## fields::aliased - create aliases for object fields
##==============================================================================
## Copyright 2004 Kevin Michael Vail
## This program is free software. It may be copied and/or redistributed under
## the same terms as Perl itself.
##==============================================================================
## $Id: aliased.pm,v 1.0 2004/09/28 02:57:30 kevin Exp $
##==============================================================================
require 5.006;

package fields::aliased;
use strict;
use warnings;
our $VERSION = '1.01';
use Carp;
use Tie::IxHash;
use Filter::Util::Call;
require fields::aliased::base;
require XSLoader;
XSLoader::load('fields::aliased', $VERSION);

##==============================================================================
## import
## - If called with an import list, assume we're in a subroutine definition and
##   deal with the field variables.
## - Otherwise, assume we're at the top of the file and pass information to
##   enable that.
## - In either case, add the source filter--it'll just output some text and
##   then disable itself.
##==============================================================================
sub import {
    no strict 'refs';
    my $class = shift;
    my ($package, $file, $line) = caller;
    tie my %variables, 'Tie::IxHash';

    if (@_) {
	##----------------------------------------------------------------------
	## Have import list, must be in a method.
	##----------------------------------------------------------------------
	unless (defined %{"$package\::FIELDS"}) {
	    croak "$package doesn't seem to have any fields defined";
	}
	my $fields = \%{"$package\::FIELDS"};

	my $selfname = shift;

	foreach my $field (@_) {
	    unless (exists $fields->{$field}) {
		croak "$field is not a valid vield in $package";
	    }
	    my $varname = field2varname($field);
	    $variables{$varname} = $field;
	}
	$variables{''} = [ $selfname, $file, $line ];
    } else {
	##----------------------------------------------------------------------
	## Assume we're at the top of the file
	##----------------------------------------------------------------------
	$variables{''} = [ undef, $file, $line ];
    }

    filter_add(\%variables);

    1;
}

##==============================================================================
## filter
##==============================================================================
sub filter {
    my ($variables) = @_;
    my ($selfname, $file, $line) = @{delete $variables->{''}};

    if (defined $selfname) {
	##----------------------------------------------------------------------
	## Create the "my" list for the field variables, then generate a call
	## to fields::aliased::setup to set up the aliases for them.
	##----------------------------------------------------------------------
	if (keys %$variables) {
	    $_ = <<".";
my (@{[join ', ', keys %$variables]});
fields::aliased::setup($selfname, qw/
.
	    chomp;
	    $_ .= join ' ', values %$variables;
	    $_ .= "/);\n";
	}
    } else {
	##----------------------------------------------------------------------
	## Create the "use base" line to add fields::aliased::base to this
	## class's ancestors.
	##----------------------------------------------------------------------
	$_ = <<".";
use base qw(fields::aliased::base);
.
    }
    ++$line;
    $_ .= qq<# line $line "$file"\n>;
    filter_del();

    1;
}

1;

##==============================================================================
## $Log: aliased.pm,v $
## Revision 1.0  2004/09/28 02:57:30  kevin
## Initial revision
##
##==============================================================================

__END__

=head1 NAME

fields::aliased - create aliases for object fields

=head1 SYNOPSIS

    package MyPackage;
    use strict;
    use fields::aliased;
    use fields qw($scalar @array %hash);

    sub new {
	my $class = shift;
	my $self = fields::aliased::new($class);
	use fields::aliased qw($self $scalar @array %hash);

	## Now access each field as a simple variable
	$scalar = 1;
	@array = (2 .. 4);
	%hash = ('one' => 1, 'two' => 2);
    }

    sub mymethod {
	my MyPackage $self = shift;
	use fields::aliased qw($self $scalar @array %hash);

	...
    }

=head1 DESCRIPTION

This module is a companion to the L<fields> module, which allows efficient
handling of instance variables with checking at compile time. It goes one step
further and actually creates lexical aliases to the instance values, which can
make code not only easier to type, but easier to read as well.

=head2 Declaring Variables

=over 4

=item *

You declare them in the C<use fields> pragma, as usual, except that you prefix
each variable with its type sigil. (For backwards compatibility, anything
without a sigil is considered to be a scalar.)

=back

=head2 Object Construction

=over 4

=item *

You must C<use fields::aliased> with no import list prior to C<use fields>. This
sets the superclass of the class to L<fields::aliased::base> so that the proper
constructor is inherited.

=item *

In your object constructor, you call L<fields::aliased::new|"new"> (or just C<<
$class->SUPER::new >>) rather than L<fields::new|fields/new>. This not only sets
up the instance variables, but initializes them to suitable defaults: empty
arrays for array variables, empty hashes for hash variables, and B<undef> for
scalars.

=back

=head2 Using Variables

=over 4

=item *

In each method that requires the use of instance variables, add the following
line:

C<< use fields::aliased qw(I<$self> I<fields>); >>

I<$self> is the name of the variable holding the object referent, and I<fields>
is the list of field names to be aliased in the method. Note that the field
names and associated variable names can be different if, for example, the field
name doesn't begin with a type sigil, or begins with an underscore (see
L<"PRIVATE FIELDS">).

=back

That's it!

=head1 CONSTRUCTOR

=over 4

=item new

C<< I<$object> = fields::aliased::new($class); >>

This is called as a subroutine, not a method, but it functions similarly to a
class method. This calls C<fields::new> to create an object of type I<$class>,
and then sets up its field variables to suitable defaults.

Note: you don't need to have C<fields::aliased> in your class's ancestry
provided that the constructor you do provide calls L<fields/new>, and
initializes all fields to suitable defaults.

=pod

=back

=head1 PRIVATE FIELDS

Field names beginning with an underscore are considered private by L<fields>. In
order to make this work with C<fields::aliased>, put the sigil I<after> the
underscore:

    use fields qw(_$private);

Then, in each method, use

    use fields::aliased qw($self _$private);

as well. But when accessing the alias, use C<$_private>.

=head1 INTERNALS

Important Note: the C code for this module uses two items defined in
L<perlintern> and thus marked not for general conception: the CvDEPTH macro, and
the C<Perl_find_runcv> function. While it works on the versions of Perl I've
tested it on (5.8.4 and 5.9.1), there's no guarantee it will work in the future.
I will try to keep on top of this.

[The only people who need to read the rest of this section are those who are
curious about how this is implemented, and me when I go back later to fix
things.]

=head2 Compile Time

At compile time, the C<use fields::aliased> lines causes the B<import> method to
be called.

=over 4

=item *

If there is no import list, the B<import> method assumes it was called from the
outside of any method, and just adds the following line to the source program:

C<< use base qw(fields::aliased::base); >>

This allows the L<constructor|"new"> to be inherited. (The separate base class
is so that the import method itself doesn't get inherited.)

=item *

If there is an import list, it consists of the name of the "self" variable and a
list of field names. In this case, the B<import> method adds two lines to the
source program:

C<< my (I<variable-names>); >>

This defines the aliased variables so the compilation of the program can proceed
successfully undef C<use strict> (you I<are> using C<strict>, right?).

C<< fields::aliased::setup($self, qw/I<field-names>/); >>

This sets up the call to the B<setup> function, which links the variables
declared above to the actual fields at runtime.

=back

=head2 Run Time

At runtime, the B<setup> function is executed to create the actual aliases.

=over 4

=item *

If I<$self> is an array reference, it is assumed to be a pseudohash (see
L<fields>), where the first element of the array is a hash associating field
names with field indices. B<setup> uses the hash in the first element to find
the field values in the rest of the elements.

=item *

If I<$self> is a hash reference, B<setup> just accesses that hash to get the
field values.

=back

=head1 SEE ALSO

L<fields>, L<Perl6::Binding>, L<Lexical::Alias>

=head1 REQUIRED MODULES

L<Tie::IxHash>, L<Filter::Util::Call>, L<Test::More>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 Kevin Michael Vail

This program is free software.	It may be copied and/or redistributed under the
same terms as Perl itself.

=head1 AUTHOR

Kevin Michael Vail <F<kvail>@F<cpan>.F<org>>
