##==============================================================================
## fields::aliased - create aliases for object fields
##==============================================================================
## Copyright 2004 Kevin Michael Vail
## This program is free software. It may be copied and/or redistributed under
## the same terms as Perl itself.
##==============================================================================
## $Id: aliased.pm,v 1.4 2004/10/05 19:45:46 kevin Exp $
##==============================================================================
require 5.006;

package fields::aliased;
use strict;
no strict 'refs';
use warnings;
our $VERSION = '1.04';
use Carp;
use Tie::IxHash;
use Filter::Util::Call;
require XSLoader;
XSLoader::load('fields::aliased', $VERSION);

##==============================================================================
## import - insert lines in the source text to enable the use of lexical aliases
## to object fields.
##==============================================================================
sub import {
    my $class = shift;
    my ($package, $file, $line) = caller;
    tie my %variables, 'Tie::IxHash';

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

    filter_add(\%variables);

    1;
}

##==============================================================================
## filter - do the actual filtering, then remove the filter.
##==============================================================================
sub filter {
    my ($variables) = @_;
    my ($selfname, $file, $line) = @{delete $variables->{''}};

    ##----------------------------------------------------------------------
    ## Create the "my" list for the field variables, then generate a call
    ## to fields::aliased::setup to set up the aliases for them.
    ##----------------------------------------------------------------------
    if (keys %$variables) {
        $_ = <<".";
my (@{[join ', ', keys %$variables]});
fields::aliased::setup($selfname, __PACKAGE__, qw/
.
        chomp;
        $_ .= join ' ', values %$variables;
        $_ .= "/);\n";
    }
    ++$line;
    $_ .= qq<# line $line "$file"\n>;
    filter_del();

    1;
}

##==============================================================================
## init
##==============================================================================
sub init {
    my ($self) = @_;
    my $class = ref $self;
    
    _init($self, $class);
}

my %initializers = (
    '$'     =>  sub { undef },
    '@'     =>  sub { [] },
    '%'     =>  sub { {} },
);

##==============================================================================
## _init - do the real work
##==============================================================================
sub _init {
    my $self = shift;
    
    foreach my $class (@_) {
        next unless defined %{"$class\::FIELDS"};
        foreach my $field_name (keys %{"$class\::FIELDS"}) {
            next if $field_name =~ /^_/;
            my ($vartype) = unpack 'a1', field2varname($field_name);
            croak "field $field_name has invalid data type"
                unless exists $initializers{$vartype};
            $self->{$field_name} = $initializers{$vartype}->();
        }
        _init($self, @{"$class\::ISA"}) if defined @{"$class\::ISA"};
    }
}

1;

##==============================================================================
## $Log: aliased.pm,v $
## Revision 1.4  2004/10/05 19:45:46  kevin
## Don't try to initialize private fields.
##
## Revision 1.3  2004/10/01 02:49:54  kevin
## Eliminate the need for the ::base module.
## Add 'init' method to take its place.
## Major revision!
##
## Revision 1.2  2004/09/29 02:34:43  kevin
## POD fix only.
##
## Revision 1.1  2004/09/29 02:12:43  kevin
## Version 1.02 adds code to the .xs part of the module.
##
## Revision 1.0  2004/09/28 02:57:30  kevin
## Initial revision
##==============================================================================

__END__

=head1 NAME

fields::aliased - create aliases for object fields

=head1 SYNOPSIS

    package MyPackage;
    use strict;
    use fields qw($scalar @array %hash);
    
    sub new {
        my $class = shift;
        my $self = fields::new($class);
        fields::aliased::init($self);

        return $self;
    }
    
    sub mymethod {
        my MyPackage $self = shift;
        use fields::aliased qw($self $scalar @array %hash);
        
        $scalar = 1;
        @array = (2 .. 4);
        %hash = ('one' => 1, 'two' => 2);
    }

=head1 DESCRIPTION

This module is a companion to the L<fields> module, which allows efficient
handling of instance variables with checking at compile time. It goes one step
further and actually creates lexical aliases to the instance values, which can
make code not only easier to type, but easier to read as well.

=head2 Declarations

You declare the fields using the L<fields> pragma, as always.

    use fields qw($scalar @array %hash nosigil);

Each field name may be preceded by a type sigil to indicate which kind of
variable it is. Names without the type sigil are treated as scalars.

For names beginning with an underscore, see L<"PRIVATE FIELDS"> below.

=head2 Constructors

You call L<fields::new|fields/new> to create the object, and then call
C<fields::aliased::init> to set the fields to suitable initial values.

    my $self = fields::new($class);
    fields::aliased::init($self);

=head2 Usage

In each method that uses the individual fields, you add a line similar to the
following:

    use fields::aliased qw($self $scalar @array %hash nosigil);

That is, list the variable being used for the object reference, and then the
names of the fields that you are going to use in this method. C<fields::aliased>
takes care of declaring the appropriate Perl lexical variables and linking them
to the appropriate field. You only need to specify the fields you are actually
going to use, including any inherited from superclasses.

=head1 PRIVATE FIELDS

The L<fields> pragma supports a means of declaring fields that are not available
to subclasses: by prefixing them with an underscore character. This module
supports that convention (actually, it has no choice!).

    use fields qw(_$private_scalar _@private_array _%private_hash);

Note that the underscore goes I<before> the type sigil; this is so that
L<fields> gets things right. However, the variable name has the sigil at the
front, as always. Thus a field named C<_$private_scalar> is linked to a variable
named C<$_private_scalar>. A field named C<_private>, of course, is linked to a
variable named C<$_private>.

=head2 Important Note

Because of the way C<use fields> works, it is not possible for
L<fields::aliased::init> to initialize private variables in superclasses, so it
skips the initialization for all field names beginning with an underscore.
Therefore, you are responsible for initializing these values yourself. For a
scalar field, this works out all right anyway, because the initial value of a
hash or array element that's never been assigned a value is B<undef>, which is
what this module would have assigned anyway. However, I<any private field
declared as an array or hash B<must> be set to an appropriate reference during
object construction> if you expect to use it in a C<use fields> statement within
a method, or you will get a run-time error.

=head1 FUNCTIONS

=over 4

=item fields::aliased::init

C<< fields::aliased::init(I<$self>); >>

This function sets all of the fields in I<$self>, including inherited fields
(but I<not> including private fields, see L<above|"PRIVATE FIELDS">), to
suitable defaults. It should be called right after L<fields::new|fields/new>.

=back

=head1 KNOWN PROBLEMS

=over 4

=item *

In Perl 5.9.1, using private fields doesn't seem to be working at all. This is
due to the switch to restricted hashes vs. pseudohashes, but I don't have all
the issues figured out yet.

=back

=head1 HISTORY

=over 4

=item 1.04

It doesn't appear to be possible to initialize private fields in a superclass in
a generic initialization method. So now we skip that and throw the
responsibility back on the programmer.

=item 1.03

Many changes to make private fields in superclasses work.

=item 1.02

Added find_funcv to .xs code.

=item 1.01

Fix distribution.

=item 1.00

Original version.

=back

=head1 SEE ALSO

L<fields>, L<Perl6::Binding>, L<Lexical::Alias>

=head1 REQUIRED MODULES

L<Tie::IxHash>, L<Filter::Util::Call>, L<Test::More>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 Kevin Michael Vail

This program is free software. It may be copied and/or redistributed under the
same terms as Perl itself.

=head1 AUTHOR

Kevin Michael Vail <F<kvail>@F<cpan>.F<org>>
