package Config::MVP::Section;
use Moose;
# ABSTRACT: one section of an MVP configuration sequence

=head1 DESCRIPTION

For the most part, you can just consult L<Config::MVP> to understand what this
class is and how it's used.

=attr name

This is the section's name.  It's a string, and it must be provided.

=cut

has name => (
  is  => 'ro',
  isa => 'Str',
  required => 1
);

=attr package

This is the (Perl) package with which the section is associated.  It is
optional.  When the section is instantiated, it will ensure that this package
is loaded.

=cut

has package => (
  is  => 'ro',
  isa => 'Str', # should be class-like string, but can't be ClassName
  required  => 0,
  predicate => 'has_package',
);

=attr multivalue_args

This attribute is an arrayref of value names that should be considered
multivalue properties in the section.  When added to the section, they will
always be wrapped in an arrayref, and they may be added to the section more
than once.

If this attribute is not given during construction, it will default to the
result of calling section's package's C<mvp_multivalue_args> method.  If the
section has no associated package or if the package doesn't provide that
method, it default to an empty arrayref.

=cut

has multivalue_args => (
  is   => 'ro',
  isa  => 'ArrayRef',
  lazy => 1,
  default => sub {
    my ($self) = @_;

    return []
      unless $self->has_package and $self->package->can('mvp_multivalue_args');

    return [ $self->package->mvp_multivalue_args ];
  },
);

=attr aliases

This attribute is a hashref of name remappings.  For example, if it contains
this hashref:

  {
    file => 'files',
    path => 'files',
  }

Then attempting to set either the "file" or "path" setting for the section
would actually set the "files" setting.

If this attribute is not given during construction, it will default to the
result of calling section's package's C<mvp_aliases> method.  If the
section has no associated package or if the package doesn't provide that
method, it default to an empty hashref.

=cut

has aliases => (
  is  => 'ro',
  isa => 'HashRef',
  default => sub {
    my ($self) = @_;

    return {} unless $self->has_package and $self->package->can('mvp_aliases');

    return $self->package->mvp_aliases;
  },
);

=attr payload

This is the storage into which properties are set.  It is a hashref of names
and values.  You should probably not alter the contents of the payload, and
should read its contents only.

=cut

has payload => (
  is  => 'ro',
  isa => 'HashRef',
  init_arg => undef,
  default  => sub { {} },
);

=method add_value

  $section->add_value( $name => $value );

This method sets the value for the named property to the given value.  If the
property is a multivalue property, the new value will be pushed onto the end of
an arrayref that will store all values for that property.

Attempting to add a value for a non-multivalue property whose value was already
added will result in an exception.

=cut

sub add_value {
  my ($self, $name, $value) = @_;

  my $alias = $self->aliases->{ $name };
  $name = $alias if defined $alias;

  my $mva = $self->multivalue_args;

  if (grep { $_ eq $name } @$mva) {
    my $array = $self->payload->{$name} ||= [];
    push @$array, $value;
    return;
  }

  if (exists $self->payload->{$name}) {
    Carp::croak "multiple values given for property $name in section "
              . $self->name;
  }

  $self->payload->{$name} = $value;
}

sub _BUILD_package_settings {
  my ($self) = @_;

  return unless defined (my $pkg  = $self->package);

  # We already inspected this plugin.
  confess "illegal package name $pkg" unless Params::Util::_CLASS($pkg);

  my $name = $self->name;
  eval "require $pkg; 1"
    or confess "couldn't load plugin $name given in config: $@";

  # We call these accessors for lazy attrs to ensure they're initialized from
  # defaults if needed.  Crash early! -- rjbs, 2009-08-09
  $self->multivalue_args;
  $self->aliases;
}

sub BUILD {
  my ($self) = @_;
  $self->_BUILD_package_settings;
}

no Moose;
1;
