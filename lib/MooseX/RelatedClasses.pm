package MooseX::RelatedClasses;

# ABSTRACT: Parameterized role for related class attributes

use MooseX::Role::Parameterized;
use namespace::autoclean;
use autobox::Core;
use MooseX::AttributeShortcuts 0.015;
use MooseX::Traits;
use MooseX::Types::Common::String ':all';
use MooseX::Types::LoadableClass ':all';
use MooseX::Types::Perl ':all';
use MooseX::Types::Moose ':all';
use MooseX::Util 'with_traits';

use Module::Find 'findallmod';

use String::CamelCase 'decamelize';
use String::RewritePrefix;

=roleparam name

The name of a class, without the prefix, to consider related.  e.g. if My::Foo
is our namespace and My::Foo::Bar is the related class:

    name => 'Bar'

...is the correct specification.

This parameter is optional, so long as either the names or all_in_namespace
parameters are given.

=roleparam names [ ... ]

One or more names that would be legal for the name parameter.

=roleparam all_in_namespace (0|1)

True if all findable packages under the namespace should be used as related
classes.  Defaults to false.

=roleparam namespace

The namespace our related classes live in.  If this is not given explicitly,
the name of the consuming class will be used as the namespace.  If the
consuming class is not available (e.g. it's being constructed by something
other than a consumer), then this parameter is mandatory.

This parameter will also accept an explicit 'undef'.  If this is the case,
then related classes must be specified by their full name and it is an error
to attempt to enable the all_in_namespace option.

e.g.:

    with 'MooseX::RelatedClasses' => {
        namespace => undef,
        name      => 'LWP::UserAgent',
    };

...will provide the C<lwp__user_agent_class>, C<lwp__user_agent_traits> and
C<original_lwp__user_agent_class> attributes.

=cut

parameter name  => (
    traits    => [Shortcuts],
    is        => 'ro',
    isa       => NonEmptySimpleStr,
    predicate => 1,
);

parameter names => (
    traits    => [Shortcuts],
    is        => 'lazy',
    isa       => ArrayRef[NonEmptySimpleStr],
    predicate => 1,
    default   => sub { [ ( $_[0]->has_name ? $_[0]->name : ()) ] },
);

parameter all_in_namespace => (
    isa     => 'Bool',
    default => 0,
);

parameter namespace => (
    traits    => [Shortcuts],
    is        => 'rwp',
    isa       => Maybe[PackageName],
    predicate => 1,
);

# TODO use rewrite prefix to look for traits in namespace

role {
    my ($p, %opts) = @_;

    # check namespace
    if (!$p->has_namespace) {

        die 'Either a namespace or a consuming metaclass must be supplied!'
            unless $opts{consumer};

        $p->_set_namespace($opts{consumer}->name);
    }

    if ($p->all_in_namespace) {

        my $ns = $p->namespace || q{};

        confess 'Cannot use an empty namespace and all_in_namespace!'
            unless $ns;

        ### finding for namespace: $ns
        my @mod =
            map { s/^${ns}:://; $_ }
            Module::Find::findallmod $ns
            ;
        $p->names->push(@mod);
    }

    _generate_one_attribute_set($p, $_, %opts)
        for $p->names->flatten;

    return;
};

sub _generate_one_attribute_set {
    my ($p, $name, %opts) = @_;

    #my $name = $p->namespace . '::' . $p->name;
    my $full_name
        = $p->namespace
        ? $p->namespace . '::' . $name
        : $name
        ;

    my $local_name           = decamelize($name) . '_class';
    $local_name              =~ s/::/__/g; # SomeThing::More -> some_thing__more
    my $original_local_name  = "original_$local_name";
    my $traitsfor_local_name = $local_name . '_traits';

    has $original_local_name => (
        traits   => [Shortcuts],
        is       => 'lazy',
        isa      => LoadableClass,
        coerce   => 1,
        init_arg => "$local_name",
    );

    has $local_name => (
        traits   => [Shortcuts],
        is       => 'lazy',
        isa      => LoadableClass,
        init_arg => undef,
    );

    # XXX do the same original/local init_arg swizzle here too?
    has $traitsfor_local_name => (
        traits  => [Shortcuts, 'Array'],
        is      => 'lazy',
        isa     => ArrayRef[LoadableRole],
        handles => {
            "has_$traitsfor_local_name" => 'count',
        },
    );

    method "_build_original_$local_name" => sub { $full_name };
    method "_build_$local_name" => sub {
        my $self = shift @_;

        return with_traits($self->$original_local_name(),
            $self->$traitsfor_local_name()->flatten,
        );
    };

    method "_build_$traitsfor_local_name" => sub { [ ] };
}

!!42;
__END__

=head1 SYNOPSIS

    # a related class...
    package My::Framework::Thinger;
    # ...

    # our "parent" class...
    package My::Framework;

    use Moose;
    use namespace::autoclean;

    # with this...
    with 'MooseX::RelatedClasses' => {
        name => 'Thinger',
    };

    # ...we get:
    has thinger_class => (
        traits  => [ Shortcuts ], # MooseX::AttributeShortcuts
        is      => 'lazy',
        isa     => PackageName, # MooseX::Types::Perl
        default => sub { ... compose original class and traits ... },
    );

    has thinger_class_traits => (
        traits  => [ Shortcuts ], # MooseX::AttributeShortcuts
        is      => 'lazy',
        isa     => ArrayRef[PackageName],
        default => sub { [ ] },
    );

    has original_thinger_class => (
        traits  => [ Shortcuts ], # MooseX::AttributeShortcuts
        is      => 'lazy',
        coerce  => 1,
        isa     => LoadableClass, # MooseX::Types::LoadableClass
        init_arg => undef,
        default => sub { 'My::Framework::Thinger' },
    );

    # multiple related classes can be handled in one shot:
    with 'MooseX::RelatedClasses' => {
        names => [ qw{ Thinger Dinger Finger } ],
    };

    # if you're using this role and the name of the class is _not_ your
    # related namespace, then you can specify it:
    with 'MooseX::RelatedClasses' => {
        # e.g. My::Framework::Recorder::Thinger
        name      => 'Thinger',
        namespace => 'My::Framework::Recorder',
    };

    # if you want to specify another class w/o any common namespace as
    # related:
    with 'MooseX::RelatedClasses' => {
        namespace => undef,
        name      => 'LWP::UserAgent',
    };

=head1 DESCRIPTION

Have you ever built out a framework, or interface API of some sort, to
discover either that you were hardcoding your related class names (not very
extension-friendly) or writing the same code for the same type of attributes
to specify what related classes you're using?

Alternatively, have you ever been using a framework, and wanted to tweak one
tiny bit of behaviour in a subclass, only to realize it was written in such a
way to make that difficult-to-impossible without a significant effort?

This package aims to end that, by providing an easy, flexible way of defining
"related classes", their base class, and allowing traits to be specified.

=head2 This is early code!

This package is very new, and is still being vetted "in use", as it were.  The
documentation (or tests) may not be 100%, but it's in active use.  Pull
requests are happily received :)

=head2 Documentation

See the SYNOPSIS for information; the tests are also useful here as well.

I _did_ warn you this is a very early release, right?

=head1 INSPIRATION / MADNESS

The L<Class::MOP> / L<Moose> MOP show the beginnings of this:  with attributes
or methods named a certain way (e.g. *_metaclass()) the class to be used for a
particular thing (e.g. attribute metaclass) is stored in a fashion such that a
subclass (or trait) may overwrite and provide a different class name to be
used.

So too, here, we do this, but in a more flexible way: we track the original
related class, any additional traits that should be applied, and the new
(anonymous, typically) class name of the related class.

Another example is the (very useful and usable) L<Net::Amazon::EC2>.  It uses
L<Moose>, is nicely broken out into discrete classes, etc, but does not lend
itself to easy on-the-fly extension by developers with traits.

=head1 ANONYMOUS CLASS NAMES

Note that we use L<MooseX::Traitor> to compose anonymous classes, so the
"anonymous names" will look less like:

    Moose::Meta::Package::__ANON__::SERIAL::...

And more like:

    My::Framework::Thinger::__ANON__::SERIAL::...

Anonymous classes are only ever composed if traits for a related class are
supplied.

=cut
