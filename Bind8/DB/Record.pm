# Base class for a Bind8 zone record
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

package Unix::Conf::Bind8::DB::Record;

use strict;
use warnings;
use Unix::Conf;
use Unix::Conf::Bind8::DB;

# Arguments
#  LABEL
#  RTYPE
#  RDATA
#  PARENT
#  CLASS
#  TTL
sub new
{
	my $class = shift ();
	my %args = ( @_ );
	my $new = bless ({}, $class);
	my $ret;

	return (Unix::Conf->_err ('new', "LABEL not specified"))
		unless (defined ($args{LABEL}));
	return (Unix::Conf->_err ('new', "RTYPE not specified"))
		unless (defined ($args{RTYPE}));
	return (Unix::Conf->_err ('new', "RDATA not specified"))
		unless (defined ($args{RDATA}));
	return (Unix::Conf->_err ('new', "PARENT not specified"))
		unless (defined ($args{PARENT}));

	$new->_parent ($args{PARENT});
	$ret = $new->class ($args{CLASS}) or return ($ret)
		if (defined ($args{CLASS}));
	$ret = $new->ttl ($args{TTL}) or return ($ret)
		if (defined ($args{TTL}));

	$ret = $new->rtype ($args{RTYPE}) or return ($ret);
	$ret = $new->rdata ($args{RDATA}) or return ($ret);
	$ret = $new->label ($args{LABEL}) or return ($ret);

	return ($new);
}

sub label
{
	my ($self, $label) = @_;
	my $ret;

	if (defined ($label)) {
		# the object is stored in a complicated datastructure keyed
		# on the label among other things. so we need to delete the 
		# old key and store the object at the new key
		if (defined ($self->{LABEL})) {
			$ret = Unix::Conf::Bind8::DB::_delete_object ($self) or return ($ret);
		}
		$self->{LABEL} = $label;
		$ret = Unix::Conf::Bind8::DB::_insert_object ($self) or return ($ret);
		$self->dirty (1);
		return (1);
	}

	return (
		defined ($self->{LABEL}) ? $self->{LABEL} :
			Unix::Conf->_err ('label', "LABEL not defined")
	);
}

# Get/Set class
sub class 
{
	my ($self, $class) = @_;

	if (defined ($class)) {
		return (Unix::Conf->_err ('class', "illegal class `$class'"))
			if ($class !~ /^(in|hs|chaos)$/i);
		return (Unix::Conf->_err ('class', "class `$class' not the same as DB class `$self->{PARENT}{CLASS}'"))
			if ($class ne $self->{PARENT}{CLASS});
		$self->{CLASS} = $class;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{CLASS}) ? $self->{CLASS} : 	
			Unix::Conf->_err ('class', "class not defined")
	)
}

# Do not allow change in RTYPE once defined
sub rtype
{
	my ($self, $rtype) = @_;

	if (defined ($rtype)) {
		return (Unix::Conf->_err ('rtype', "RTYPE already defined"))
			if (defined ($self->{RTYPE}));
		$self->{RTYPE} = $rtype;
		return (1);
	}
	return ($self->{RTYPE});
}

sub ttl 
{
	my ($self, $ttl) = @_;

	if (defined ($ttl)) {
		return (Unix::Conf->_err ('ttl', "illegal ttl `$ttl'"))
			unless (__is_validttl ($ttl));
		$self->{TTL} = $ttl;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{TTL}) ? $self->{TTL} : 
			Unix::Conf->_err ('ttl', "TTL not defined")
	)
}

sub rdata
{
	my ($self, $rdata) = @_;

	if (defined ($rdata)) {
		# the object is stored in a complicated datastructure keyed
		# on the rdata among other things. so we need to delete the 
		# old key and store the object at the new key
		if (defined ($self->{RDATA})) {
			my $ret;
			$ret = Unix::Conf::Bind8::DB::_delete_object ($self) 
				or return ($ret);
			# change rdata now before storing in new location as it is
			# depenedant on the rdata.
			$self->{RDATA} = $rdata;
			return (Unix::Conf::Bind8::DB::_insert_object ($self));
			$self->dirty (1);
		}

		$self->{RDATA} = $rdata;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{RDATA}) ? $self->{RDATA} :
			Unix::Conf->_err ('rdata', "RDATA not defined")
	);
}

# this is used to set the memeber PARENT which points to the hash in
# which we are contained. This helps us set the dirty flag in case
# we are modified.
sub _parent
{
	my ($self, $parent) = @_;

	if (defined ($parent)) {
		# Don't allow changing value once defined.
		return (Unix::Conf->_err ('parent', "PARENT already defined"))
			if (defined ($self->{PARENT})); 
		$self->{PARENT} = $parent;
		return (1);
	}
	return (
		defined ($self->{PARENT}) ? $self->{PARENT} :
			Unix::Conf->_err ('parent', "PARENT not defined")
	);
}

# we set the dirty flag in the containing object using the PARENT member.
sub dirty
{
	my ($self, $dirty) = @_;

	if (defined ($dirty)) {
		$self->{PARENT}{DIRTY} = $dirty;
		return (1);
	}
	return ($self->{PARENT}{DIRTY});
}

sub delete
{
	return (Unix::Conf::Bind8::DB::_delete_object ($_[0]));
	$_[0]->dirty (1);
}


1;
__END__
