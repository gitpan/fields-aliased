##==============================================================================
## t/fields-aliased.t - test file for fields::aliased
##==============================================================================
## $Id: fields-aliased.t,v 1.0 2004/09/28 02:57:31 kevin Exp $
##==============================================================================
require 5.006;

use Test::More tests => 5;

##==============================================================================
## Create a package that uses fields to define instance variables.
##==============================================================================
package Testing;
use strict;
use fields::aliased;
use fields qw($scalar @array %hash nosigil);
Test::More::ok(1);

sub method {
	my Testing $self = shift;
	use fields::aliased qw($self $scalar @array %hash nosigil);

	$scalar = 1;
	$array[1] = 7;
	$hash{'foo'} = 'bar';
	$nosigil = 4;

	Test::More::ok($self->{'nosigil'} == 4);
	Test::More::ok($self->{'@array'}[1] == 7);
	Test::More::ok($self->{'$scalar'} == 1);
	Test::More::ok($self->{'%hash'}{'foo'} eq 'bar');
}

##==============================================================================
## Then create an instance of the object and check things out.
##==============================================================================
package main;
use strict;

my $object = new Testing;

$object->method;

##==============================================================================
## $Log: fields-aliased.t,v $
## Revision 1.0  2004/09/28 02:57:31  kevin
## Initial revision
##
##==============================================================================
