BEGIN {
    package X;
    use Test::More tests => 26;
    use strict;
    use warnings;
    use fields::aliased qw(
    	$scalar @array %hash
    );

    ok(1);

    sub set_testvars {
        field vars : my $self;

        $scalar = 'one';
        @array = ( qw/two three/ );
        %hash = ( 'four' => 4, 'five' => 5 );

        ok( $self->{'scalar'} eq 'one' );
        ok( $self->{'array'}[0] eq 'two' && $self->{'array'}[1] eq 'three' );
        ok( $self->{'hash'}{'four'} == 4 && $self->{'hash'}{'five'} == 5 );
    }

    sub examine_testvars {
        field vars : my $self;

        ok( $scalar eq 'one' );
        ok( $array[0] eq 'two' && $array[1] eq 'three' );
        ok( $hash{'four'} == 4 && $hash{'five'} == 5 );

        $scalar = 'won';
        ok( $self->{'scalar'} eq 'won' );
        ok( \$scalar == \$self->{'scalar'} );

        $self->nested_testvars;
    }

    sub examine_two {
        (my X $self) = @_;
        field vars : $self;

        ok( $scalar eq 'won' );
        ok( $array[0] eq 'two' && $array[1] eq 'three' );
        ok( $hash{'four'} == 4 && $hash{'five'} == 5 );

        ok( \$scalar == \$self->{'scalar'} );

        $self->nested_testvars;
    }

    sub nested_testvars {
        field vars : my $self;

        ok( $scalar eq 'won' );
        ok( $array[0] eq 'two' && $array[1] eq 'three' );
        ok( $hash{'four'} == 4 && $hash{'five'} == 5 );
    }

    sub recursive_testvars {
        field vars : my $self;
        my ($level) = @_;

        ok( defined $scalar && $scalar eq 'won' );

        unless ($level) {
            $self->recursive_testvars($level + 1);
        }
    }

    sub comments {
##		field vars : my $self;
		ok(1);
	}

    sub fancy {
    	field vars : my $self (
    		$scalar, %hash, @array,
    	);

    	ok( defined $scalar && $scalar eq 'won' );
    	ok( $array[0] eq 'two' and $array[1] eq 'three' );
    	ok( $hash{'four'} == 4 && $hash{'five'} == 5 );
    }
	ok(__LINE__ == 85);
}

package main;

my $t = X->new;

$t->set_testvars;
$t->examine_testvars;
$t->examine_two;
$t->recursive_testvars(0);
$t->fancy;
$t->comments;
