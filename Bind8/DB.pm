# Bind8 DB handling
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8::DB - Class implementing methods for manipulation of
a Bind records file.

=head1 SYNOPSIS

Refer to the SYNOPSIS section for Unix::Conf::Bind8

=head1 DESCRIPTION

This class has interfaces for the various classes residing
beneath Unix::Conf::Bind8::DB. This class should not be 
accessed directly. Methods in this class are to be accessed
through a Unix::Conf::Bind8::DB object which is returned
by Unix::Conf::Bind8->new_db () or by invoking the get_db ()
object method in Unix::Conf::Bind8::Conf or Unix::Conf::Bind8::Conf::Zone.
Refer to the relevant documentation for further details.

=over 4

=cut

package Unix::Conf::Bind8::DB;

use strict;
use warnings;

use Unix::Conf;
use Unix::Conf::Bind8::DB::SOA;
use Unix::Conf::Bind8::DB::NS;
use Unix::Conf::Bind8::DB::MX;
use Unix::Conf::Bind8::DB::A;
use Unix::Conf::Bind8::DB::PTR;
use Unix::Conf::Bind8::DB::CNAME;
use Unix::Conf::Bind8::DB::Lib;

#
# Unix::Conf::Bind8::DB object
# 
# SCALARREF -> {
#                 FH
#                 ORIGIN
#                 CLASS
#                 DIRTY
#				  SOA
#				  RECORDS -> {
#							   DATA      -> {
#                                              'label' -> {
#                                                           'rtype' -> {
#                                                                        'rdata'
#                                                                      }
#                                                         }
#                                           }
#                              CHILDREN   -> {
#                                              'label' -> {
#                                                           DATA
#                                                           CHILDREN
#                                                         }
#                                            }
#                            }
#			   }
#
# Zone: 
#           example.com
# Records:
#           example.com			IN	A 	10.0.0.1
#			ns.example.com		IN  A	10.0.0.2
#			ns.sub.example.com	IN	A	10.0.0.3
#
#               RECORDS -> {
#							   DATA      -> {
#                                              '' -> {
#                                                      'A' -> {
#                                                               '10.0.0.1' -> Unix::Conf::Bind8::DB::A object
#                                                             }
#                                                    }
#                                              'ns' -> {
#                                                      'A' -> {
#                                                               '10.0.0.2' -> Unix::Conf::Bind8::DB::A object
#                                                             }
#                                                    }
#                                           }
#                              CHILDREN   -> {
#                                              'sub' -> {
#                                                         DATA -> {
#                                                                     'ns' -> {
#                                                                                'A' -> {
#                                                                                         '10.0.0.2' -> Unix::Conf::Bind8::DB::A object
#                                                                                       }
#                                                                             }
#                                                                 }
#                                                       }
#                                            }
#                          }
#
# The way this is stored, almost all the information is duplicated in both the object
# and the tree. But this seems to be the only way out if we want to come up with a
# DB object containing other record objects setup. This is done here to maintain
# uniformity with Bind8::Conf where the constituent objects in a Bind8::Conf object
# are complicated and different enough to warrant their own classes.
#

=item new ()

 Arguments
 FILE        => 'pathname',   # 
 ORIGIN      => 'value',      # origin
 CLASS       => 'class',      # ('in'|'hs'|'chaos')
 SECURE_OPEN => 0/1,          # optional (enabled (1) by default)

Class constructor
Creates a Unix::Conf::Bind8::DB object and returns it if
successful, an Err object otherwise. Direct use of this method 
is deprecated. Use Unix::Conf::Bind8::Zone::get_db (), or 
Unix::Conf::Bind8::new_db () instead.

=cut

# ARGUMENTS: hash
#	FILE
#	ORIGIN
#	CLASS
#	SECURE_OPEN
# RETURN
# 	Unix::Conf::Bind8::DB/Unix::Conf::Err object
# The object created is a ref to a scalar which contains a ref
# to a hash. This is to break the circular reference problem.
sub new
{
	my $invocant = shift ();
	my %args = @_;
	my ($new, $db, $ret);

	$args{FILE} || return (Unix::Conf->_err ('new', "DB file not specified"));	
	$args{ORIGIN} || return (Unix::Conf->_err ('new', "DB origin not specified"));
	$args{ORIGIN} .= "." unless (__is_absolute ($args{ORIGIN}));
	$args{CLASS} || return (Unix::Conf->_err ('new', "DB class not specifed"));
	$args{SECURE_OPEN} = defined ($args{SECURE_OPEN}) ?  $args{SECURE_OPEN} : 1;
	$db = Unix::Conf->_open_conf (
		NAME => $args{FILE}, SECURE_OPEN => $args{SECURE_OPEN} 
	) or return ($db);
	# we are blessing a reference to a hashref.
	$new = bless (\{ RECORDS => {}, DIRTY => 0 });
	$$new->{FH} = $db;
	$ret = $new->origin ($args{ORIGIN}) or return ($ret);
	$ret = $new->class ($args{CLASS}) or return ($ret);
	# check for any syntax probs in the classes. change parser later.
	eval { $ret = $new->__parse_db (); } or return ($@);
	return ($new);
}

sub DESTROY
{
	my $self = $_[0];

	if ($$self->{DIRTY}) {
		my $fh = $self->fh ();
		my $str = __render ($self);
		$fh->set_scalar ($str);
	}
	# release all contained stuff
	undef (%$$self);
}

=item origin ()

 Arguments
 'origin',   # optional. if the argument is not absolute, i.e.
             # having a trailing '.', the existing origin, if
		     # any will be appended to the argument.

Object method.
Get/Set DB origin. If argument is passed, the method tries to set the
origin of the DB object to 'origin' and returns true on success, an Err
object otherwise. If no argument is specified, returns the name of the
zone, if defined, an Err object otherwise. 

=cut

sub origin
{
	my ($self, $origin) = @_;
	
	if (defined ($origin)) {
		$$self->{ORIGIN} = __is_absolute ($origin) ? $origin :
			(defined ($$self->{ORIGIN}) ? $origin.$$self->{ORIGIN} : $origin.'.');
		return (1);
	}
	return (
		defined ($$self->{ORIGIN}) ? $$self->{ORIGIN} : Unix::Conf->_err ('origin', "origin not defined")
	);
}

=item fh ()

Object method.
Returns the Unix::Conf::ConfIO object representing the DB file.

=cut

sub fh
{
	my $self = $_[0];
	return ($$self->{FH});
}

=item dirty ()

Object method.
Get/Set the DIRTY flag in invoking Unix::Conf::Bind8::DB object.

=cut

sub dirty
{
	my ($self, $dirty) = @_;

	if (defined ($dirty)) {
		$$self->{DIRTY} = $dirty;
		return (1);
	}
	return ($$self->{DIRTY});
}

=item class ()

 Arguments
 'class'      # ('in'|'hs'|'chaos')

Object method.
Get/Set object class. If argument is passed, the method tries to set the 
class attribute to 'class' and returns true if successful, an Err object
otherwise. If no argument is passed, returns the value of the class 
attribute if defined, an Err object otherwise.

=cut

# Typically class is set in the zone statement. Each record can have a 
# zone specified. But that cannot be different from the value set here.
sub class
{
	my ($self, $class) = @_;

	if (defined ($class)) {
		return (Unix::Conf->_err ('class', "illegal class `$class'"))
			if ($class !~ /^(in|hs|chaos)$/i);
		$$self->{CLASS} = $class;
		$$self->{DIRTY} = 1;
		return (1);
	}
	return (
		defined ($$self->{CLASS}) ? $$self->{CLASS} : Unix::Conf->_err ('class', "class not defined")
	);
}

=item new_soa ()

 Arguments
 CLASS   =>
 TTL     =>
 AUTH_NS =>
 MAIL_ADDR   =>
 SERIAL  =>
 REFRESH =>
 RETRY   =>
 EXPIRE  =>
 MIN_TTL =>

Object method.
Creates and associates a new Unix::Conf::Bind8::DB::SOA object 
with the invoking Unix::Conf::Bind8::DB object and returns it
on success, an Err object otherwise.

=cut

# The only new_* method where this method adds the SOA to the
# the DB object. In other methods it is done by the corresponding
# new_* constructors.
sub new_soa
{
	my $self = shift ();
	my (%args, $new);
	return (Unix::Conf->_err ('new_soa', "SOA already defined"))
		if ($$self->{SOA});
	%args = ( @_ );
	# make sure an illegal class is not set.
	return (Unix::Conf->_err ('new_soa', "illegal class `$args{CLASS}'for SOA"))
		if ($args{CLASS} ne $$self->{CLASS});
	$new = Unix::Conf::Bind8::DB::SOA->new ( @_, RTYPE => 'SOA', PARENT => $$self ) or Unix::Conf->_err ($new);
	$$self->{DIRTY} = 1;
	return ($$self->{SOA} = $new);
}

=item get_soa ()

Object method.
Returns the Unix::Conf::Bind8::DB::SOA object associated with the invoking
Unix::Conf::Bind8::DB object if defined, an Err object otherwise.

=cut

sub get_soa
{
	my $self = $_[0];

	return (
		$$self->{SOA} ? $$self->{SOA} : Unix::Conf->_err ('get_soa', "SOA not defined")
	);
}

=item delete_soa ()

Object method.
Deletes the Unix::Conf::Bind8::DB::SOA object associated with the invoking
Unix::Conf::Bind8::DB object if defined and returns true, an Err object 
otherwise.

=cut

sub delete_soa
{
	return (Unix::Conf->_err ('delete_soa', "SOA not defined"))
		unless ($$_[0]->{SOA});
	delete ($$_[0]->{SOA});
	return (1);
}

=item new_ns ()

 Arguments
 LABEL		=>
 RTYPE		=>
 RDATA		=>
 CLASS		=>
 TTL		=>

Object method.
Creates and associates a new Unix::Conf::Bind8::DB::NS object 
with the invoking Unix::Conf::Bind8::DB object and returns it
on success an Err object otherwise.

=cut

=item new_a ()

 Arguments
 LABEL		=>
 RTYPE		=>
 RDATA		=>
 CLASS		=>
 TTL		=>

Object method.
Creates and associates a new Unix::Conf::Bind8::DB::A object 
with the invoking Unix::Conf::Bind8::DB object and returns it
on success an Err object otherwise.

=cut

=item new_mx ()

 Arguments
 LABEL		=>
 RTYPE		=>
 MXPREF		=>
 RDATA		=>
 CLASS		=>
 TTL		=>

Object method.
Creates and associates a new Unix::Conf::Bind8::DB::MX object 
with the invoking Unix::Conf::Bind8::DB object and returns it
on success an Err object otherwise.

=cut

=item new_ptr ()

 Arguments
 LABEL		=>
 RTYPE		=>
 RDATA		=>
 CLASS		=>
 TTL		=>

Object method.
Creates and associates a new Unix::Conf::Bind8::DB::PTR object 
with the invoking Unix::Conf::Bind8::DB object and returns it
on success an Err object otherwise.

=cut

=item new_cname ()

 Arguments
 LABEL		=>
 RTYPE		=>
 RDATA		=>
 CLASS		=>
 TTL		=>

Object method.
Creates and associates a new Unix::Conf::Bind8::DB::CNAME object 
with the invoking Unix::Conf::Bind8::DB object and returns it
on success an Err object otherwise.

=cut

=item get_ns ()

 Arguments
 'label',
 'rdata'			# optional

Object method.
Returns the Unix::Conf::Bind8::DB::NS object associated with the
invoking Unix::Conf::Bind8::DB object, with label 'label' and
rdata 'rdata'. If the rdata argument is not passed, then all
NS record objects attached to label 'label' are returned in
an anonymous array. On failure an Err object is returned.

=cut

=item get_a ()

 Arguments
 'label',
 'rdata'			# optional

Object method.
Returns the Unix::Conf::Bind8::DB::A object associated with the
invoking Unix::Conf::Bind8::DB object, with label 'label' and
rdata 'rdata'. If the rdata argument is not passed, then all
A record objects attached to label 'label' are returned in
an anonymous array. On failure an Err object is returned.

=cut

=item get_mx ()

 Arguments
 'label',
 'rdata'			# optional

Object method.
Returns the Unix::Conf::Bind8::DB::MX object associated with the
invoking Unix::Conf::Bind8::DB object, with label 'label' and
rdata 'rdata'. If the rdata argument is not passed, then all
MX record objects attached to label 'label' are returned in
an anonymous array. On failure an Err object is returned.

=cut

=item get_ptr ()

 Arguments
 'label',
 'rdata'			# optional

Object method.
Returns the Unix::Conf::Bind8::DB::PTR object associated with the
invoking Unix::Conf::Bind8::DB object, with label 'label' and
rdata 'rdata'. If the rdata argument is not passed, then all
PTR record objects attached to label 'label' are returned in
an anonymous array. On failure an Err object is returned.

=cut

=item get_cname ()

 Arguments
 'label',
 'rdata'			# optional

Object method.
Returns the Unix::Conf::Bind8::DB::CNAME object associated with the
invoking Unix::Conf::Bind8::DB object, with label 'label' and
rdata 'rdata'. If the rdata argument is not passed, then all
CNAME record objects attached to label 'label' are returned in
an anonymous array. On failure an Err object is returned.

=cut

=item set_ns ()

 Arguments
 'label',
 [
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	....
 ],

Object method.
Creates and associates Unix::Conf::Bind8::DB::NS objects with the 
relevant attributes with the invoking Unix::Conf::Bind8::DB object.
Returns true on success, an Err object otherwise. The existing
Unix::Conf::Bind8::DB::NS objects attached to this label are
deleted.

=cut

=item set_a ()

 Arguments
 'label',
 [
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	....
 ],

Object method.
Creates and associates Unix::Conf::Bind8::DB::A objects with the 
relevant attributes with the invoking Unix::Conf::Bind8::DB object.
Returns true on success, an Err object otherwise. The existing
Unix::Conf::Bind8::DB::A objects attached to this label are
deleted.

=cut

=item set_mx ()

 Arguments
 'label',
 [
 	{ CLASS => 'class', TTL => 'ttl', MXPREF => pref, RDATA => 'rdata',  },
 	{ CLASS => 'class', TTL => 'ttl', MXPREF => pref, RDATA => 'rdata',  },
 	....
 ],

Object method.
Creates and associates Unix::Conf::Bind8::DB::MX objects with the 
relevant attributes with the invoking Unix::Conf::Bind8::DB object.
Returns true on success, an Err object otherwise. The existing
Unix::Conf::Bind8::DB::MX objects attached to this label are
deleted.

=cut

=item set_ptr ()

 Arguments
 'label',
 [
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	....
 ],

Object method.
Creates and associates Unix::Conf::Bind8::DB::PTR objects with the 
relevant attributes with the invoking Unix::Conf::Bind8::DB object.
Returns true on success, an Err object otherwise. The existing
Unix::Conf::Bind8::DB::PTR objects attached to this label are
deleted.

=cut

=item set_cname ()

 Arguments
 'label',
 [
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	{ CLASS => 'class', TTL => 'ttl', RDATA => 'rdata',  },
 	....
 ],

Object method.
Creates and associates Unix::Conf::Bind8::DB::CNAME objects with the 
relevant attributes with the invoking Unix::Conf::Bind8::DB object.
Returns true on success, an Err object otherwise. The existing
Unix::Conf::Bind8::DB::CNAME objects attached to this label are
deleted.

=cut

=item delete_ns ()

 Arguments
 'label',
 'rdata',

Object method.
Deletes the Unix::Conf::Bind8::DB::NS object with label 'label' and rdata 'rdata', 
associated with the invoking Unix::Conf::Bind8::DB object if defined and returns 
true, an Err object. If the rdata argument is not passed, then all NS records
attached to label 'label' are deleted.

=cut

=item delete_a ()

 Arguments
 'label',
 'rdata',

Object method.
Deletes the Unix::Conf::Bind8::DB::A object with label 'label' and rdata 'rdata', 
associated with the invoking Unix::Conf::Bind8::DB object if defined and returns 
true, an Err object. If the rdata argument is not passed, then all A records
attached to label 'label' are deleted.

=cut

=item delete_mx ()

 Arguments
 'label',
 'rdata',

Object method.
Deletes the Unix::Conf::Bind8::DB::MX object with label 'label' and rdata 'rdata', 
associated with the invoking Unix::Conf::Bind8::DB object if defined and returns 
true, an Err object. If the rdata argument is not passed, then all MX records
attached to label 'label' are deleted.

=cut

=item delete_ptr ()

 Arguments
 'label',
 'rdata',

Object method.
Deletes the Unix::Conf::Bind8::DB::PTR object with label 'label' and rdata 'rdata',
associated with the invoking Unix::Conf::Bind8::DB object if defined and returns 
true, an Err object. If the rdata argument is not passed, then all PTR records
attached to label 'label' are deleted.

=cut

=item delete_cname ()

 Arguments
 'label',
 'rdata',

Object method.
Deletes the Unix::Conf::Bind8::DB::CNAME object with label 'label' and rdata 'rdata',
associated with the invoking Unix::Conf::Bind8::DB object if defined and returns 
true, an Err object. If the rdata argument is not passed, then all CNAME records
attached to label 'label' are deleted.

=cut

for my $rtype qw (NS A MX PTR CNAME) 
{
	no strict 'refs';
	# new_*
	my $meth = lc ($rtype);
	*{"new_$meth"} = sub {
		my $self = shift ();
		return ("Unix::Conf::Bind8::DB::$rtype"->new ( @_, RTYPE => $rtype, PARENT => $$self ));
	};

	*{"get_$meth"} = sub {
		my ($self, $label, $rdata) = @_;
		return (Unix::Conf->_err ("get_$meth", "label not specified"))
			unless (defined ($label));
		my $node = __get_node ($$self, $label);
		return (Unix::Conf->_err ("get_$meth", "$rtype record for `$label' not defined"))
			unless ($node->{$rtype});
		# get a record with value of $rdata for $label
		if (defined ($rdata)) {
			return (Unix::Conf->_err ("get_$meth", "$rtype record for `$label' with rdata of `$rdata' not defined"))
				unless ($node->{$rtype}{$rdata});
			return ($node->{$rtype}{$rdata});
		}
		# else return all records for of that particular RTYPE for $label
		return ( [ values (%{$node->{$rtype}}) ] );
	};

	my $delmeth = "delete_$meth";
	my $newmeth = "new_$meth";
	*{"set_$meth"} = sub {
		my ($self, $label, $rdata) = @_;
		return (Unix::Conf->_err ("set_$meth", "label not specified"))
			unless (defined ($label));
		return (Unix::Conf->_err ("set_$meth", "RDATA not specified"))
			unless ($rdata);
		my $ret;
		# first delete all old values
		$ret = $delmeth->($self, $label) or return ($ret);
		for (@$rdata) {
			$_->{LABEL} = $label;
			$ret = $newmeth->($self, %{$_}) or return ($ret);
		}
		return (1);
	}; 

	*$delmeth = sub {
		my ($self, $label, $rdata) = @_;
		return (Unix::Conf->_err ("delete_$meth", "label not specified"))
			unless (defined ($label));
		my $node = __get_node ($$self, $label);
		return (Unix::Conf->_err ("delete_$meth", "$rtype record for `$label' not defined"))
			unless ($node->{$rtype});

		# delete the $rtype record with value $rdata for $label
		if (defined ($rdata)) {
			$rdata = __make_relative ($$self->{ORIGIN}, $rdata);
			return (Unix::Conf->_err ("delete_$meth", "$rtype record for `$label' with rdata of `$rdata' not defined"))
				unless ($node->{$rtype}{$rdata});
			delete ($node->{$rtype}{$rdata});
			$self->dirty (1);
			return (1);
		}

		# else delete all $rtype records for $label
		delete ($node->{$rtype});
		$self->dirty (1);
		return (1);
	};
}

# Utility functions used to insert/delete objects from the database tree
# ARGUMENT: Unix::Conf::Bind8::DB::Record or derived object. 
sub _insert_object
{
	my $object = $_[0];

	return (Unix::Conf->_err ('_insert_object', "Record object not specified"))
		unless ($object);
	return (Unix::Conf->_err ('_insert_object', "Record object not a child class of type Unix::Conf::Bind8::DB::Record"))
		unless ($object->isa ('Unix::Conf::Bind8::DB::Record'));
	my $root = $object->_parent ();

	my ($label, $rtype, $rdata);
	defined ($label = $object->label ()) or return ($label);
	$rtype = $object->rtype () or return ($rtype);
	$rdata = $object->rdata () or return ($rdata);
	$rdata = __make_relative ($root->{ORIGIN}, $rdata);

	my $node = __get_node ($root, $label);
	return (Unix::Conf->_err ('_insert_object', "Record with label `$label' of type `$rtype' with data `$rdata' already defined"))
		if ($node->{$rtype}{$rdata});
	return ($node->{$rtype}{$rdata} = $object);
}

# ARGUMENT: Unix::Conf::Bind8::DB::Record or derived object. 
sub _delete_object
{
	my $object = $_[0];

	return (Unix::Conf->_err ('_delete_object', "Record object not specified"))
		unless ($object);
	return (Unix::Conf->_err ('_delete_object', "Record object not a child class of type Unix::Conf::Bind8::DB::Record"))
		unless ($object->isa ('Unix::Conf::Bind8::DB::Record'));
	my $root = $object->_parent ();
	my ($label, $rtype, $rdata);
	defined ($label = $object->label ()) or return ($label);
	$rtype = $object->rtype () or return ($rtype);
	$rdata = $object->rdata () or return ($rdata);
	$rdata = __make_relative ($root->{ORIGIN}, $rdata);

	my $node = __get_node ($root, $label);
	return (Unix::Conf->_err ('_delete_object', "Record with label `$label' of type `$rtype' with data `$rdata' not defined"))
		unless ($node->{$rtype}{$rdata});
	delete ($node->{$rtype}{$rdata});
	return (1);
}

#sub _get_object
#{
#	my ($root, $label, $rtype, $rdata) = @_;
#
#	return (Unix::Conf->_err ('_get_object', "label not specified"))
#		unless (defined ($label));
#	return (Unix::Conf->_err ('_get_object', "rtype not specified"))
#		unless (defined ($rtype));
#	return (Unix::Conf->_err ('_get_object', "rdata not specified"))
#		unless (defined ($rdata));
#
#	my $node = __get_node ($root, $label);
#	return (Unix::Conf->_err ('_get_object', "Record with label `$label' of type `$rtype' with data `$rdata' not defined"))
#		unless ($node->{$rtype}{$rdata});
#	return ($node->{$rtype}{$rdata});
#}

#
# NOTE: For an origin of 'test.net' a rec for test.net will be attached
# to test.net with a label of '', which one for leaf.test.net will be attached
# to test.net with a label of 'leaf'.
# $root is the hashref that is contained in a Unix::Conf::Bind8::DB object.
#
sub __get_node
{
	my ($root, $olabel) = @_;
	my $label;
	return (Unix::Conf->_err ('__get_node', "`$olabel' lies outside `$root->{ORIGIN}'"))
		unless (defined ($label = __make_relative ($root->{ORIGIN}, $olabel)));
	# use regex to pull out a pattern so that the $leaf will be '', not undef
	# in case of $label being ''
	my ($leaf, $nodes) = ($label =~ /^((?:[\w-]+)?)\.?(.*)$/);
	my $ptr = $root->{RECORDS};
	# traverse the tree
	for (reverse (split (/\./, $nodes))) {
		# if this part of the tree doesn't exist create it.
		$ptr->{CHILDREN}{$_} = {} unless (defined ($ptr->{CHILDREN}{$_}));
		$ptr = $ptr->{CHILDREN}{$_}
	}
	$ptr->{DATA}{$leaf} = {}	unless ($ptr->{DATA}{$leaf});
	return ($ptr->{DATA}{$leaf});
}

# shared amongst __render_tree and __render
my ($Rendered, $Class, $DB_Origin);

# forward declaration
sub __render_tree ($$$);
sub __render
{
	my $self = $_[0];
	$DB_Origin = $$self->{ORIGIN};
	$Class = $self->class ();

	# render SOA for the zone
	$Rendered = "\$ORIGIN $DB_Origin\n@\t";
	$Rendered .= "$$self->{SOA}{TTL}\t" if (defined ($$self->{SOA}{TTL}));
	my $auth_ns = __make_absolute ($DB_Origin, $$self->{SOA}{AUTH_NS});
	my $mail_addr = __make_absolute ($DB_Origin, $$self->{SOA}{MAIL_ADDR});
	$Rendered .= "$Class\tSOA\t$auth_ns\t$mail_addr (\n\t\t$$self->{SOA}{SERIAL}\n\t\t$$self->{SOA}{REFRESH}\n\t\t$$self->{SOA}{RETRY}\n\t\t$$self->{SOA}{EXPIRE}\n\t\t$$self->{SOA}{MIN_TTL})\n";

	__render_tree ($$self->{RECORDS}, $DB_Origin, 1);
	return (\$Rendered);
}

sub __render_tree ($$$)
{
	my ($node, $origin, $origin_printed) = @_;
	# print ORIGIN
	my $start = "\n";
	$start .= "\$ORIGIN $origin\n" unless ($origin_printed);

	# print all nodes in this level
	for my $label (keys (%{$node->{DATA}})) {
		$start .= "$label";
		for my $rectype (keys (%{$node->{DATA}{$label}})) {
			for my $rec (keys (%{$node->{DATA}{$label}{$rectype}})) {
				my ($obj, $tmp);
				# print this only if there are records
				if ($start) { $Rendered .= $start; undef ($start); }
				#else 		{ $Rendered .= "\t"; }
				$Rendered .= "\t";
				$obj = $node->{DATA}{$label}{$rectype}{$rec};
				$Rendered .= "$tmp\t"
					if ($tmp = $obj->ttl ());
				$Rendered .= "$Class\t\U$rectype\E\t";
				$Rendered .= "$tmp\t"
					if ($rectype eq 'MX' && ($tmp = $obj->mxpref ()));
				# any relative labels are relative to DB_Origin. so make it abs
				# then relative to last printed origin before printing
				if ($rectype ne 'A') {
					$Rendered .= sprintf ("%s\n", __make_relative ($origin, __make_absolute ($DB_Origin, $rec)));
				}
				else {
					$Rendered .= "$rec\n";
				}
			}
		}
		# this is to be sure that the label in $start from the last iteration
		# is not carried. 
		undef ($start);
	}
	for my $child (keys (%{$node->{CHILDREN}})) {
		__render_tree ($node->{CHILDREN}{$child}, "$child.$origin", 0);
	}
}

#################################  PARSER  #####################################
#                                                                              #
require 'Unix/Conf/Bind8/DB/Parser.pm';
#                                   END                                        #
#################################  PARSER  #####################################

1;
__END__
