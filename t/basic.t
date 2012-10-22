use Test::More;
use Test::Moose::More 0.014;
use Moose::Util::TypeConstraints 'class_type';

use MooseX::Types::Moose ':all';

{
    package TestClass;

    use Moose;
    use namespace::autoclean;

    with 'MooseX::RelatedClasses' => {
        name => 'Baz',
    };

}
{ package TestClass::Baz; use Moose; use namespace::autoclean }

with_immutable {

    validate_class 'TestClass' => (
        attributes => [
            baz_class => {
                reader   => 'baz_class',
                isa      => class_type('TestClass::Baz'),
                lazy     => 1,
                init_arg => undef,
            },
            baz_class_traits => {
                traits => ['Array'],
                reader    => 'baz_class_traits',
                handles => { has_baz_class_traits => 'count' },
                builder   => '_build_baz_class_traits',
                isa       => ArrayRef[class_type('TestClass::Baz')],
                lazy      => 1,
            },
            original_baz_class => {
                reader   => 'original_baz_class',
                isa      => class_type('TestClass::Baz'),
                lazy     => 1,
                init_arg => 'baz_class',
            },
        ],
        methods => [ qw{ _build_baz_class } ],
    );

    my $tc = TestClass->new;

    is $tc->baz_class(), 'TestClass::Baz', 'baz_class() is correct';

} 'TestClass';

done_testing;
