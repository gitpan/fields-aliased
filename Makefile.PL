use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'fields::aliased',
    VERSION_FROM      => 'lib/fields/aliased.pm',
    PREREQ_PM         => {
        'Tie::IxHash'       =>  '1.21',
        'Lexical::Util'     =>  '0.1',
        'Filter::Simple'    =>  '0.78',
        'Test::More'        =>  '0.47',
    },
    ABSTRACT_FROM     => 'lib/fields/aliased.pm',
    AUTHOR            => 'Kevin Michael Vail <kevin@vaildc.net>',
);
