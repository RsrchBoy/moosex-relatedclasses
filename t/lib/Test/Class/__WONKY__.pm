package Test::Class::__WONKY__;

use Moose;
use namespace::autoclean;

with 'MooseX::RelatedClasses' => {
    all_in_namespace => 1,
};

!!42;
__END__
