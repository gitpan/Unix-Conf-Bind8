# Bind8 SOA record handling
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

package Unix::Conf::Bind8::DB::SOA;

use strict;
use warnings;

use Unix::Conf;
use Unix::Conf::Bind8::DB;
use Unix::Conf::Bind8::DB::Lib;
use Unix::Conf::Bind8::DB::Record;

our @ISA = qw (Unix::Conf::Bind8::DB::Record);

# class constructor.
# Arguments: hash
#	PARENT	=>
#   CLASS   =>
#   TTL     =>
#   AUTH_NS =>
#   MAIL_ADDR   =>
#   SERIAL  =>
#   REFRESH =>
#   RETRY   =>
#   EXPIRE  =>
#   MIN_TTL =>
#
sub new 
{
	my $class = shift ();
	my %args = @_;
	my $new = bless ({}, $class);
	my $ret;

	return (Unix::Conf->_errr ('new', "`PARENT' not specified"))
		unless (defined ($args{PARENT}));
	$ret = $new->_parent ($args{PARENT}) or return ($ret);
	# check all arguments in the loop and call appropriate methods to set them
	for my $key qw (AUTH_NS MAIL_ADDR SERIAL REFRESH RETRY EXPIRE MIN_TTL RTYPE) {
		return (Unix::Conf->_err ('new', "`$key' not specified"))
			unless (defined ($args{$key}));
		my $meth = lc ($key);
		$ret = $new->$meth ($args{$key}) or return ($ret);
	}
	return ($new);
}

sub auth_ns
{
	my ($self, $auth_ns) = @_;

	if (defined ($auth_ns)) {
		$self->{AUTH_NS} = $auth_ns;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{AUTH_NS}) ? $self->{AUTH_NS} :
			Unix::Conf->_err ('auth_ns', "AUTH_NS not defined")
	);
}

sub mail_addr
{
	my ($self, $mail_addr) = @_;

	if (defined ($mail_addr)) {
		$self->{MAIL_ADDR} = $mail_addr;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{MAIL_ADDR}) ? $self->{MAIL_ADDR} :
			Unix::Conf->_err ('mail_addr', "MAIL_ADDR not defined")
	);
}

sub serial
{
	my ($self, $serial) = @_;

	if (defined ($serial)) {
		return (Unix::Conf->_err ('serial', "illegal SERIAL value `$serial'"))
			unless ($serial =~ /^\d+$/);
		$self->{SERIAL} = $serial;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{SERIAL}) ? $self->{SERIAL} :
			Unix::Conf->_err ('mail_addr', "SERIAL not defined")
	);
}

for my $meth qw (refresh retry expire min_ttl) {
	no strict 'refs';

	*$meth = sub {
		my ($self, $arg) = @_;
		my $key = uc ($meth);
		if (defined ($arg)) {
			return (Unix::Conf->_err ("$meth", "illegal $key value `$arg'"))
				unless (__is_validttl ($arg));
			$self->{$key} = $arg;
			$self->dirty (1);
			return (1);
		}
		return (
			defined ($self->{$key}) ? $self->{$key} :
				Unix::Conf->_err ("$meth", "`$key' not defined")
		)
	};
}

1;
