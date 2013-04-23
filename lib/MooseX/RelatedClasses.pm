#
# This file is part of MooseX-RelatedClasses
#
# This software is Copyright (c) 2012 by Chris Weyl.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package MooseX::RelatedClasses;
{
  $MooseX::RelatedClasses::VERSION = '0.004';
}

# ABSTRACT: Parameterized role for related class attributes

use MooseX::Role::Parameterized;
use namespace::autoclean;
use autobox::Core;
use autobox::Camelize;
use MooseX::AttributeShortcuts 0.019;
use MooseX::Types::Common::String ':all';
use MooseX::Types::LoadableClass ':all';
use MooseX::Types::Perl ':all';
use MooseX::Types::Moose ':all';
use MooseX::Util 'with_traits';

use Module::Find 'findallmod';

use Class::Load 'load_class';
use String::RewritePrefix;

# debugging...
#use Smart::Comments '###';


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

parameter load_all => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

parameter private => (is => 'ro', isa => 'Bool', default => 0);

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
            map { s/^${ns}:://; $_                   }
            map { load_class($_) if $p->load_all; $_ }
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

    my $full_name
        = $p->namespace
        ? $p->namespace . '::' . $name
        : $name
        ;

    my $pvt = $p->private ? '_' : q{};

    # SomeThing::More -> some_thing__more
    my $local_name           = $name->decamelize . '_class';
    my $original_local_name  = "original_$local_name";
    my $original_reader      = "$pvt$original_local_name";
    my $traitsfor_local_name = $local_name . '_traits';
    my $traitsfor_reader     = "$pvt$traitsfor_local_name";

    ### $full_name
    has "$pvt$original_local_name" => (
        traits     => [Shortcuts],
        is         => 'lazy',
        isa        => LoadableClass,
        constraint => sub { $_->isa($full_name) },
        coerce     => 1,
        init_arg   => "$pvt$local_name",
        builder    => sub { $full_name },
    );

    has "$pvt$local_name" => (
        traits     => [Shortcuts],
        is         => 'lazy',
        isa        => LoadableClass,
        constraint => sub { $_->isa($full_name) },
        coerce     => 1,
        init_arg   => undef,
        builder    => sub {
            my $self = shift @_;

            return with_traits( $self->$original_reader() =>
                $self->$traitsfor_reader()->flatten,
            );
        },
    );

    # XXX do the same original/local init_arg swizzle here too?
    has "$pvt$traitsfor_local_name" => (
        traits  => [Shortcuts, 'Array'],
        is      => 'lazy',
        isa     => ArrayRef[LoadableRole],
        builder => sub { [ ] },
        handles => {
            "${pvt}has_$traitsfor_local_name" => 'count',
        },
    );

    return;
}

!!42;

__END__

=pod

=encoding utf-8

=for :stopwords Chris Weyl Parameterized

=head1 NAME

MooseX::RelatedClasses - Parameterized role for related class attributes

=head1 VERSION

This document describes version 0.004 of MooseX::RelatedClasses - released April 22, 2013 as part of MooseX-RelatedClasses.

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
        traits     => [ Shortcuts ], # MooseX::AttributeShortcuts
        is         => 'lazy',
        isa        => LoadableClass, # MooseX::Types::LoadableClass
        constraint => sub { $_->isa('Thinger') }, # MX::AttributeShortcuts
        builder    => sub { ... compose original class and traits ... },
    );

    has thinger_class_traits => (
        traits  => [ Shortcuts ],
        is      => 'lazy',
        isa     => ArrayRef[LoadableRole],
        builder => sub { [ ] },
    );

    has original_thinger_class => (
        traits     => [ Shortcuts ],
        is         => 'lazy',
        isa        => LoadableClass,
        constraint => sub { $_->isa('Thinger') },
        coerce     => 1,
        init_arg   => undef,
        builder    => sub { 'My::Framework::Thinger' },
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

=head1 ROLE PARAMETERS

Parameterized roles accept parameters that influence their construction.  This role accepts the following parameters.

=head2 name

The name of a class, without the prefix, to consider related.  e.g. if My::Foo
is our namespace and My::Foo::Bar is the related class:

    name => 'Bar'

...is the correct specification.

This parameter is optional, so long as either the names or all_in_namespace
parameters are given.

=head2 names [ ... ]

One or more names that would be legal for the name parameter.

=head2 all_in_namespace (Bool)

True if all findable packages under the namespace should be used as related
classes.  Defaults to false.

=head2 namespace

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

=head2 load_all (Bool)

If set to true, all related classes are loaded as we find them.  Defaults to
false.

=head2 private (Bool)

If true, attributes, accessors and builders will all be named according to the
same rules L<MooseX::AttributeShortcuts> uses.  (That is, in general prefixed
with an "_".)

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

=head1 SOURCE

The development version is on github at L<http://github.com/RsrchBoy/moosex-relatedclasses>
and may be cloned from L<git://github.com/RsrchBoy/moosex-relatedclasses.git>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/RsrchBoy/moosex-relatedclasses/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Chris Weyl <cweyl@alumni.drew.edu>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Chris Weyl.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
