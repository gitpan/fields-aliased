##==============================================================================
## fields::aliased - alias members created by the 'fields' pragma
##==============================================================================
## Copyright 2004 Kevin Michael Vail
## This program is free software. It may be copied and/or redistributed under
## the same terms as Perl itself.
##==============================================================================
## $Id: aliased.pm,v 0.6 2004/06/06 05:59:20 kevin Exp $
##==============================================================================
require 5.006;

package ## don't want this indexed yet
	fields::aliased;
use strict;
use warnings;
our $VERSION = '0.4';

use Tie::IxHash;
use Carp;
use Filter::Simple;

##------------------------------------------------------------------------------
## These are kludges because I can't think of a good way to get this information
## from the call to FILTER. They're set by the call to 'import'.
##------------------------------------------------------------------------------
my ($_package, $_filename, $_line);

our $DEBUG;

=head1 NAME

fields::aliased - alias members created by the 'fields' pragma

=head1 DESCRIPTION

C<fields::aliased> extends the L<fields|fields> pragmatic module to make
compile-time class fields even easier to use...you get them aliased to lexical
variables so that you don't have to constantly dereference the object within
methods.

As an example, let's take the following inane excerpt of a class named Example:

	package Example;
	use strict;
	use fields qw(scalar array hash);

	## Constructor
	sub new {
	    my $self = fields::new(shift);

	    $self->{scalar} = 3;
	    $self->{array}  = [];
	    $self->{hash}   = {};

	    return $self;
	}

	sub sample_method {
	    my ($self) = @_;

	    $self->{array}[0] = 'yup';
	    print $self->{scalar}, "\n";
	}

The exact same effect could be achieved by the following:

	package Example;
	use strict;
	use fields::aliased qw($scalar @array %hash);

	## Constructor
	sub new {
	    my $self = shift->SUPER::new;
	    field vars : $self;

	    $scalar = 3;

	    return $self;
	}

	sub sample_method {
	    field vars : my $self (@array, $scalar);

	    $array[0] = 'yup';
	    print $scalar, "\n";
	}

They perform the same operations, but you don't have to type C<< $self-> >>
around all of the fields. This can make code much easier to read, especially for
arrays and hashes.

=head1 DECLARING FIELDS

C<< use fields::aliased qw(I<$scalar> I<@array> I<%hash>); >>

C<< use fields::aliased qw(:strict I<$scalar> I<@array> I<%hash>); >>

You declare fields similar to the way you do using L<fields|fields>. The
difference is that you precede each one with a type character to indicate what
kind of data it will store, just as when declaring regular variables. Specifying
C<use fields::aliased> not only declares the variables, but it installs a source
filter (see L<Filter::Simple|Filter::Simple>) that takes care of inserting the
appropriate declarations into methods when needed.

The word C<:strict> occurring in the list requires all fields to be explicitly
named when used in a method.

=head1 CREATING FIELDS

C<< my I<$object> = fields::aliased::new(I<$class>); >>

The class that uses C<fields::aliased> automatically has a class inserted into
its C<@ISA> array which provides a constructor (see L<"new">) that automatically
sets up the fields and give them suitable initial value. If you provide your own
constructor, be sure to call the superclass's method.

You don't need to know if I<$object> is an array or a hash, and in fact it could
change between versions of Perl, since pseudohashes (the current implementation,
as of 5.8.4) are scheduled to go away in 5.10.

=head1 USING FIELDS

C<< S<< field vars [ : [ my ] I<$self> ] [ ( I<$var1> [, ...] ) ] >> >>

This is the part that makes it all worthwhile. To access the fields defined for
an object, use a C<field vars> statement somewhere near the beginning of the
method. The various parts are explained below.

=over 4

=item C<< field vars >>

This part is constant.

=item C<< : I<$self> >>

Specifies the variable to be used as the object reference for access to the
fields. This variable must have been declared and set prior to the C<< field
vars >> statement.

=item C<< : my I<$self> >>

As above, but in addition declares I<$self> and assigns it a value by shifting
the first element of C<@_> into it.

If neither form is specified, the fields are accessed via C<$_[0]>, but this is
not removed from C<@_> or stored anywhere.

(Note that the variable can be named anything, but it I<must> be a simple scalar
variable.)

=item C<< ( I<$var1>, ... ) >>

You may specify an optional list of variables to restrict the aliased fields to
just those variables. It is an error to name a variable for which a
corresponding field was not declared.

If you don't specify a list of variables, all applicable fields have lexical
variables aliased to them.

If you specify the word C<:strict> anywhere in the list of fields to be created
(at C<use fields::aliased> time), then only variables named in the list will be
aliased, and a fatal error will be given if the list isn't specified.

Private variables in superclasses can't be specified in this list, and don't
have aliases created for them if the list isn't specified.

=back

Once you've executed this statement, you access the fields in your object
reference as if they were simple scalar variables.

=head1 METHODS

The following methods are automatically added to the class that calls C<use
fields::aliased>:

=over 4

=item new

C<< I<$object> = new I<$class>; >>

Creates an object of I<$class> and returns a reference to it. The fields defined
for the object, including inherited fields, are all created and suitably
initialized.

=item create_aliases

C<< I<$object>->create_aliases('I<varname>' ...); >>

Creates lexical variables in its caller aliased to the corresponding fields in
I<$object>. This is called by the code introduced as a result of the C<field
vars> statement; you shouldn't ever have an occasion to use it directly.

=item pedigree

C<< I<@list> = I<$class>->pedigree; >>

C<< I<@list> = I<$object>->pedigree; >>

Returns the list of classes that comprise the specified class, starting with
I<$class> itself and continuing on up, in the order Perl will search for
methods.

=back

=head1 NOTES

=over 4

=item *

This whole thing is currently experimental. It seems to work, but for now you
should probably avoid using it in really important code.

=item *

Because of the way C<use fields> works, you can't have two fields with the same
name even if they are different types. For example, you couldn't have both
C<@var> and C<$var> defined. You will get a compile-time error message if you
try this, even if one of the variables is inherited.

=item *

Also, because of the way C<use fields> works, you can B<only> use single
inheritance for any classes that have fields defined. If the B<fields> pragma
(actually, the L<base|base> pragma) somehow doesn't detect this, the
L<"fields::aliased::new"> method will. It's a fatal error either way.

=item *

If for some reason you have a class split across two or more files, you must
either place all fields in one file or make sure that all component files are
seen at compile time, prior to a C<field vars> being encountered in any of them.

=item *

If you split the class across multiple files and have defined all fields in one
of them, you must include a C<use fields::aliased;> line in each of the others
in order to be sure the C<field vars> statements are properly compiled.

=item *

If you define more than one class in the same source file, you must turn off the
filtering by using

C<< no fields::aliased; >>

prior to beginning the new package.

=item *

If you seem to be having a problem with the generated code, you can set the
variable C<$fields::aliased::DEBUG> to a true value to cause the generated code
to be sent to standard output. This must be done in a BEGIN block prior to the
"use fields::aliased" line in order to have the desired effect. The odds are
that no one but me will ever have to do this, though.

=back

=head1 DIAGNOSTICS

=over 4

=item multiple definition of variable: I<name>

The named variable was declared multiple times, each time with the same type.

=item I<name1> already defined as I<name2>

The same field name has been used for variables of different types, e.g.
C<$vars> and C<@vars>.

=item I<name1> already defined as I<name2> in I<class>

The same member name was used multiple times in different classes, with
different types.

=item invalid variable name: I<name>

The specified field name is not a valid Perl identifier.

=item invalid item in import list: I<item>

An item was seen in the import list on the C<use fields::aliased> line that was
neither a valid Perl variable name nor the word C<:strict>.

=item no such field I<varname>

There is no field corresponding to I<varname>.

=item variable 'I<name>' doesn't match type of field

The type (scalar, array, or hash) of variable I<name> doesn't match that of the
value stored in the specified field.

=item must specify variable list when ':strict' is specified

You didn't.

=item invalid field variables: I<list>

The items specified appeared in the variable list of a C<field vars> statement,
but not in the actual list of fields.

=back

=head1 PREREQUISITES

L<Tie::IxHash|Tie::IxHash>,
L<Filter::Simple|Filter::Simple>,
L<Lexical::Util|Lexical::Util>

=head1 SEE ALSO

L<Alias|Alias>, L<Lexical::Alias|Lexical::Alias>,
L<Perl6::Binding|Perl6::Binding>

=head1 HISTORY

=over 4

=item 0.4

Numerous fixes relating to edge cases.

Error messages should now reference the proper line and file.

=item 0.3

We now ignore 'field vars' if it's preceded by # on the same line.

The #line directives should now be correct.

Added $DEBUG flag.

=item 0.2

Fixed the example code so it actually compiles and runs. (Thanks to Slaven Rezic
for finding this.)

Changed to allow trailing whitespace and/or a trailing comma at the end of the
variable list in the C<field vars> statement.

=item 0.1

Initial release, May 31, 2004.

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2004 Kevin Michael Vail

This program is free software.  It may be copied and/or redistributed under the
same terms as Perl itself.

=head1 AUTHOR

Kevin Michael Vail <F<kevin>@F<vaildc>.F<net>>

=cut

##==============================================================================
## import
##==============================================================================
sub import {
    my $class = shift;
    ($_package, $_filename, $_line) = caller;
    my @message;
    no strict 'refs';

    unless (tied %{"$_package\::FIELDALIASES"}) {
        tie %{"$_package\::FIELDALIASES"}, 'Tie::IxHash';
    }
    my $vars = \%{"$_package\::FIELDALIASES"};

    foreach (@_) {
        if ($_ eq ':strict') {
            $vars->{$_} = 1;
        } elsif (/^([\$\@\%])(\w+)$/) {
            my ($type, $name) = ($1, $2);
            if ($name =~ /^[A-Za-z_]\w*$/) {
                if (exists $vars->{$name}) {
                    if ($type eq $vars->{$name}) {
                        push @message,
                            "multiple definition of variable: $type$name";
                    } else {
                        push @message,
                            "$type$name already defined as $vars->{$name}$name";
                    }
                } else {
                    $vars->{$name} = $type;
                }
            } else {
                push @message, "invalid variable name: $type$_";
            }
        } else {
            push @message, "invalid item in import list: $_";
        }
    }
    croak join "\n", @message if @message;

    1;
}

##==============================================================================
## FILTER
##==============================================================================
FILTER {
    no strict 'refs';
    return unless length;

    print "*** $_filename:\n" if $DEBUG;

    my $output = <<"__";
use fields qw(@{[join ' ', keys %{"$_package\::FIELDALIASES"}]});
BEGIN { our \@ISA; push \@ISA, 'fields::aliased::_base'; }
#line @{[++$_line]} "$_filename"
__
    print $output if $DEBUG;
    my $fvars = \%{"$_package\::FIELDALIASES"};

    while (
        /^(.*?)                         ## everything up to 'field vars' in $1
         (                              ## Save rest of matched stuff in $2
           field\s+vars                 ## match the command
           (?:\s*:\s*(my)?\s*           ## $3 becomes 'my' or nothing
              (\$[^\s;]+)\s*            ## $4 becomes $self-reference if present
           )?                           ## whole thing is optional
           (?:\s*                       ## next is variable list, if present
             (                          ## save into $5
              \(\s*                     ## it's wrapped in parentheses
               (?:[\$\@\%]\w+           ## one variable name
                  (?:\s*(?:,\s*)+[\s\@\%]\w+)*
                  [\s,]*                ## can be followed by extra commas
               )?                       ## the variable name part is optional
              \)
             )
           )?
           \s*;[ \t]*\n?                ## terminated by a semicolon
         )                              ## end of stuff saved in $2
         (.*)$                          ## rest of program into $7
        /sx
    ) {
        my (
            $prefix, $all, $myflg, $selfvar, $vars, $suffix
        ) = ($1, $2, $3, $4, $5, $6);
        my (%vars, %myvars, $hadlist, $generated);

        $_line += $prefix =~ tr/\n/\n/;
        my $prior_line = $_line;
        $generated = qq{#line $_line "$_filename\n};
        $_line += ($all =~ tr/\n/\n/);

        if ($prefix =~ /^(.*#.*)\Z/m || $prefix =~ /(\\)\Z/) {
            my $match = $1;
            print "## skipping 'field vars' on line $prior_line\n"
                if $DEBUG && $DEBUG == 1;
            $prefix =~ s/\\\Z// unless $match =~ /#/;
            $output .= $prefix . $all;
            print $prefix, $all if $DEBUG && $DEBUG > 1;
            $_ = $suffix;
            next;
        }

        $prefix =~ s/[ \t]+$//;

        $output .= $prefix;
        print $prefix if $DEBUG && $DEBUG > 1;

        if (defined $selfvar) {
            if ($myflg) {
                $generated .= qq{my __PACKAGE__ $selfvar = shift;\n};
            }
        } else {
            $selfvar = '$_[0]';
        }

        my $errortail = "at $_filename line $_line";
        if (defined $vars && $vars =~ /\S/) {
            if ($vars =~ /^\((.*)\)$/) {
                %vars = map { ( $_ => 1 ) } split m/\s*,\s*/, $1;
                $hadlist = 1;
            }
        } elsif (exists $fvars->{':strict'}) {
            die << "__";
must specify variable list when ':strict' is specified $errortail
__
        }

        foreach my $class ($_package->fields::aliased::_base::pedigree) {
            next unless defined %{"$class\::FIELDALIASES"};
            my $vars = \%{"$class\::FIELDALIASES"};

            while (my ($varname, $type) = each %$vars) {
                if ($class eq $_package || $varname !~ /^_/) {
                    if (exists $myvars{$varname}) {
                        my ($otype, $oclass) = @{$myvars{$varname}};
                        die <<"__" if $type ne $otype;
$type$varname already defined as $otype$varname in $class $errortail
__
                    } else {
                        $myvars{$varname} = [ $type, $class ];
                    }
                }
            }
        }
        if ($hadlist) {
            my %temp;
            my @bad;

            foreach (keys %vars) {
                my ($type, $name) = unpack 'a1a*', $_;
                if (exists $myvars{$name}) {
                    $temp{$name} = $myvars{$name};
                } else {
                    push @bad, $_;
                }
            }
            %myvars = %temp;

            die <<"__" if @bad;
invalid field variables: @{[join ', ', @bad]} $errortail
__
        }
        if (keys %myvars) {
            $generated .= <<"__";
my (@{[join ', ', map { "$myvars{$_}[0]$_" } sort keys %myvars]});
$selfvar->create_aliases(
__
            my $temp = '    ' . join ",\n    ", map {
                qq{'$myvars{$_}[0]$_'}
            } sort keys %myvars;
            $generated .= $temp;
            $generated .= "\n);\n";
        }
        $generated .= <<"__";
#line $_line "$_filename"
__

        print $generated if $DEBUG;
        $output .= $generated;
        $_ = $suffix;
    }
    print if $DEBUG && $DEBUG > 1;
    $output .= $_;
    $_ = $output;
};

package ## don't index this, either
    fields::aliased::_base;
use strict;
use warnings;

use Carp;
use Tie::IxHash;
use Lexical::Util qw(lexalias frame_to_cvref);

##------------------------------------------------------------------------------
## The defaults are used to assign initial values to created variables.
##------------------------------------------------------------------------------
my %defaults = (
    '$' =>  sub { undef },
    '@' =>  sub { my @array; return \@array },
    '%' =>  sub { my %hash; return \%hash },
);

##------------------------------------------------------------------------------
## The types are used to check that an alias-to-be and its reference have the
## same type.
##------------------------------------------------------------------------------
my %reftypes = (
    '$' => '',
    '@' => 'ARRAY',
    '%' => 'HASH',
);

sub _recursive_pedigree ($\%@);

##==============================================================================
## new
##==============================================================================
sub new {
    my $package = shift;
    my $self = fields::new($package);

    foreach my $class ($package->pedigree) {
        no strict 'refs';
        next unless defined %{"$class\::FIELDALIASES"};
        my $vars = \%{"$class\::FIELDALIASES"};

        while (my ($varname, $type) = each %$vars) {
            $self->{$varname} = $defaults{$type}->();
        }
    }

    return $self;
}

##==============================================================================
## create_aliases
##==============================================================================
sub create_aliases {
    my $self = shift;
    my $cv = frame_to_cvref(1);

    foreach (@_) {
        my ($type, $member) = unpack 'a1a*', $_;

        unless (exists $self->{$member}) {
            croak "no such field '$type$member'";
        }

        unless (exists $reftypes{$type}
             && $reftypes{$type} eq ref $self->{$member}) {
            croak <<"__";
Variable '$type$member' doesn't match type of field
__
        }
        lexalias(
            $cv, $_, $type eq '$' ? \$self->{$member} : $self->{$member}
        );
    }
}

##==============================================================================
## pedigree
##==============================================================================
sub pedigree {
    my ($proto) = @_;
    my $class = ref $proto ? ref $proto : $proto;
    no strict 'refs';
    tie my %pedigree, 'Tie::IxHash';

    _recursive_pedigree $class, %pedigree, @{"$class\::ISA"};

    return keys %pedigree;
}

##==============================================================================
## _recursive_pedigree($class, \%pedigree, @ancestors);
##==============================================================================
sub _recursive_pedigree ($\%@) {
    my ($class, $pedigree, @ancestors) = @_;
    no strict 'refs';

    $pedigree->{$class} = 1;
    foreach (@ancestors) {
        _recursive_pedigree $_, %$pedigree, @{"$_\::ISA"};
    }
}

1;

##==============================================================================
## $Log: aliased.pm,v $
## Revision 0.6  2004/06/06 05:59:20  kevin
## Numerous fixes for edge cases.
##
## Revision 0.5  2004/06/06 02:30:13  kevin
## Get the #line directives correct, and add $DEBUG variable.
##
## Revision 0.4  2004/06/06 00:54:19  kevin
## Numerous fixes.
##
## Revision 0.3  2004/05/31 08:51:03  kevin
## Fix bug handling list of variables.
##
## Revision 0.2  2004/05/31 06:50:56  kevin
## Store field information in FIELDALIASES hash in each package.
##
## Revision 0.1  2004/05/31 06:32:51  kevin
## Initial revision
##==============================================================================
