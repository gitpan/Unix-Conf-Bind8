# Bind8 ACL implementation
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8::Conf::Acl - Class for representing a Bind8 configuration
file ACL.

=head1 SYNOPSIS

    use Unix::Conf::Bind8;
    my ($conf, $acl, $ret);
    $conf = Unix::Conf::Bind8->new_conf (
        FILE        => '/etc/named.conf',
        SECURE_OPEN => 1,
    ) or $conf->die ("couldn't open `named.conf'");

    # get an existing acl named 'extremix.net-slaves'
    $acl = $conf->get_acl ('extremix.net-slaves')
        or $acl->die ("couldn't get ACL `extremix.net-slaves');

    # or create a new one
    $acl = $conf->new_acl ( 
        NAME     => 'extremix.com-slaves', 
        ELEMENTS => [ qw (element1 element2) ],
    ) or $acl->die ("couldn't create `extremix.com-slaves'");

    # set the elements of the ACL. old values are deleted
    $ret = $acl->elements ([ qw (10.0.0.1 10.0.0.2) ])
        or $ret->die ("couldn't set elements on ACL `extremix.net-slaves'");

    # add elements
    $ret = $acl->add_elements ([ qw (10.0.0.3 10.0.0.4) ])
        or $ret->die ("couldn't add elements to ACL `extremix.net-slaves'");
    
=head1 METHODS

=cut

package Unix::Conf::Bind8::Conf::Acl;

use strict;
use warnings;

use Unix::Conf;
use Unix::Conf::Bind8::Conf::Directive;
our @ISA = qw (Unix::Conf::Bind8::Conf::Directive);

use Unix::Conf::Bind8::Conf::Lib;

=over 4

=item new ()

 Arguments
 NAME       => 'ACL-NAME',
 ELEMENTS   => [ qw (element1 element2) ],

Class constructor.
Creates a new Unix::Conf::Bind8::Conf::Acl object and returns it if successful,
an Err object otherwise.
Direct use of this method is deprecated. Use Unix::Conf::Bind8::Conf::new_acl ()
instead.

=cut

sub new
{
	my $class = shift ();
	my $new = bless ({});
	my %args = @_;
	my $ret;

	# PARENT need not necessarily be set as this constructor is called
	# from Unix::Conf::Bind8::Conf::Zone::new for adding unnamed ACLs
	$ret = $new->_parent ($args{PARENT}) or return ($ret)
		if ($args{PARENT});
	if ($args{NAME}) {
		$ret = $new->name ($args{NAME}) or return ($ret);
		$args{WHERE} = 'LAST' unless ($args{WHERE});
		$ret = Unix::Conf::Bind8::Conf::_insert_in_list ($new, $args{WHERE}, $args{WARG})
			or return ($ret);
	}
	$ret = $new->elements ($args{ELEMENTS} || []) or return ($ret);
	return ($new);
}

=item name ()

 Arguments
 'ACL-NAME'     # optional

Object method.
Get/Set the object's name attribute. If argument is passed, the method tries 
to set the name attribute to 'ACL-NAME' and returns true if successful, an 
Err object otherwise. If no argument passed, it returns the name.

=cut

sub name
{
	my ($self, $name) = @_;

	if (defined ($name)) {
		my $ret;

		__valid_string ($name);
		# already defined. changing name
		if ($self->{name}) {
			$ret = Unix::Conf::Bind8::Conf::_del_acl ($self) or return ($ret);
		}
		$self->{name} = $name;
		$ret = Unix::Conf::Bind8::Conf::_add_acl ($self) or return ($ret);
		$self->dirty (1);
		return (1);
	}
	return ($self->{name});
}

=item elements ()

 Arguments
 [ qw (element1 element2 element3) ],    # optional

Object method.
Get/Set the object's elements attribute. If an array reference is passed
as argument, the method tries to set the elements attribute to the members 
of the array reference as argument. It returns true on success, an Err 
object otherwise. If no argument is passed, returns an array reference 
consisting of the elements of the object if defined, an Err object 
otherwise.

=cut

sub elements
{
	my ($self, $elements) = @_;

	if (defined ($elements)) {
		for (@$elements) {
			return (Unix::Conf->_err ('elements', "illegal ACL element `$_'"))
				if (! __valid_element ($_));
		}
		# reinit values
		$self->{elements} = {};
		#local $" = ",";
		@{$self->{elements}}{@$elements} = (1) x @$elements;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{elements}) ? [ keys (%{$self->{elements}}) ] :
			Unix::Conf->_err ('elements', "elements not set for this acl")
	);
}

=item add_elements ()

 Arguments
 [ qw (element2 element3) ],

Object method.
Adds the elements of the array reference passed as argument to the elements
of the invocant object. Returns true on success, an Err object otherwise.

=cut

sub add_elements
{
	my ($self, $elements) = @_;

	if (defined ($elements)) {
		for (@$elements) {
			return (Unix::Conf->_err ('add_element', "illegal ACL element `$_'"))
				if (! __valid_element ($_));
		}
		$self->{elements}{@$elements} = (1) x @$elements;
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_element', "elements to be added not specified"));
}

=cut delete_elements ()

 Arguments
 [ qw (element1 element2) ],

Object method.
Deletes elements specified in the array reference as argument and returns
true on success, an Err object otherwise.

=cut

sub delete_elements 
{
	my ($self, $elements) = @_;

	if (defined ($elements)) {
		for (@$elements) {
			return (Unix::Conf->_err ('delete_elements', "`$_' not defined"))
				unless ($self->{elements}{$_});
		}
		map { delete ($self->{elements}{$_}) } @$elements;
	}
	return (Unix::Conf->_err ('delete_elements', "elements to be deleted not specified"));
}

# Instance method
# Arguments: NONE
sub __render
{
	my ($name, $rendered);
	
	$rendered = "acl $name {\t\n"
		if ($name = $_[0]->name ());
	local $" = "; ";
	$rendered .= "\t@{$_[0]->elements ()};\n";
	$rendered .= "};\n"
		if (defined ($name));
	return ($_[0]->_rstring (\$rendered));
}

1;
__END__
