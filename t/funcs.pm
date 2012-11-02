
# debugging...
#use Smart::Comments '###';

use autobox::Core;
use MooseX::Types::Moose ':all';

sub related {
    my ($namespace, $related) = @_;

    $namespace    .= '::' if $namespace ne q{};
    my $class_name = $namespace . $related;
    my $class_type = class_type $class_name;
    my $flat       = $related->split(qr/::/)->join('__')->lc;

    my $test_hash = {
        attributes => [
            (
                "${flat}_class" => {
                    reader   => "${flat}_class",
                    isa      => $class_type,
                    lazy     => 1,
                    init_arg => undef,
                },
                "${flat}_class_traits" => {
                    traits  => ['Array'],
                    reader  => "${flat}_class_traits",
                    handles => { "has_${flat}_class_traits" => 'count' },
                    builder => "_build_${flat}_class_traits",
                    isa     => ArrayRef[$class_type],
                    lazy    => 1,
                },
                "original_${flat}_class" => {
                    reader   => "original_${flat}_class",
                    isa      => $class_type,
                    lazy     => 1,
                    init_arg => "${flat}_class",
                },
            ),
        ],
        methods => [ "_build_${flat}_class" ],
    };

    ### $test_hash
    return $test_hash;
}

!!42;
