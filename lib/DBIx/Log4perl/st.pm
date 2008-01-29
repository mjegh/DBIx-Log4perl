# $Id: st.pm 284 2006-09-07 13:50:57Z martin $
use strict;
use warnings;
use DBI;
use Log::Log4perl;

package DBIx::Log4perl::st;
@DBIx::Log4perl::st::ISA = qw(DBI::st DBIx::Log4perl);
use DBIx::Log4perl::Constants qw (:masks $LogMask);

sub finish {
    my ($sth) = shift;
    my $h = $sth->{private_DBIx_Log4perl};
    
    $sth->_dbix_l4p_debug('finish')
	if ($h->{logmask} & DBIX_L4P_LOG_INPUT);
    return $sth->SUPER::finish;
}

#
# NOTE: execute can be called from the DBD. Now we support retrieving
# dbms_output from DBD::Oracle we need a flag to say we are in the
# 'dbms_output_get' or when we call dbms_output_get we will log a second
# execute and potentially recurse until we run out of stack.
# We use the "dbd_specific" flag since we may need it for other
# drivers in the future and that is the logging flag we implement dbms_output
# fetching under
#
sub execute {
    my ($sth, @args) = @_;
    my $h = $sth->{private_DBIx_Log4perl};

    $sth->_dbix_l4p_debug('execute', @args)
      if (($h->{logmask} & DBIX_L4P_LOG_INPUT) &&
	  (caller !~ /^DBD::/) &&
	  (!$h->{dbd_specific}));

    my $ret = $sth->SUPER::execute(@args);

    #
    # If DBDSPECIFIC is enabled and this is DBD::Oracle we will attempt to
    # to retrieve any dbms_output. However, 'dbms_output_get' actually
    # creates a new statement, prepares it, executes it, binds parameters
    # and then fetches the dbms_output. This will cause this execute method
    # to be called again and we could recurse forever. To prevent that
    # happening we set {dbd_specific} flag before calling dbms_output_get
    # and clear it afterwards.
    #
    # Also in DBI (at least up to 1.54) and most DBDs, the same memory is
    # used for a dbh errstr/err/state and each statement under it. As a
    # result, if you sth1->execute (it fails) then $sth2->execute which
    # succeeds, sth1->errstr/err are undeffed :-(
    # see http://www.nntp.perl.org/group/perl.dbi.users/2007/02/msg30971.html
    # To sort this out, we save the errstr/err/state on the first sth
    # and put them back after using the second sth (ensuring we temporarily
    # turn off any error handler to avoid set_err calling them again).
    #
    if (($h->{logger}->is_debug()) &&
        ($h->{logmask} & DBIX_L4P_LOG_DBDSPECIFIC) &&
    	($h->{driver} eq 'Oracle') && (!$h->{dbd_specific})) {
	my ($errstr, $err, $state) = (
	    $sth->errstr, $sth->err, $sth->state);
    	$h->{dbd_specific} = 1;
    	my $dbh = $sth->FETCH('Database');
        
        my @lines = $dbh->func('dbms_output_get');
    	$sth->_dbix_l4p_debug('dbms', @lines) if (scalar(@lines) > 0);
    	$h->{dbd_specific} = 0;
	{
	    local $sth->{HandleError} = undef;
	    local $sth->{HandleSetErr} = undef;
	    $sth->set_err($err, $errstr, $state);
	}
    }

    if (!$ret) {		# error
	$h->{logger}->error("\tfailed with " . DBI::neat($sth->errstr))
	    if (($h->{logmask} & DBIX_L4P_LOG_ERRCAPTURE) && # logging errors
		(caller !~ /^DBD::/)); # not called from DBD e.g. execute_array
    } elsif (defined($ret) && (!$h->{dbd_specific})) {
        $sth->_dbix_l4p_debug('affected', $ret)
	    if ((!defined($sth->{NUM_OF_FIELDS})) && # not a result-set
		($h->{logmask} & DBIX_L4P_LOG_INPUT)	&& # logging input
		(caller !~ /^DBD::/));
    }
    return $ret;
}

sub execute_array {
    my ($sth, @args) = @_;
    my $h = $sth->{private_DBIx_Log4perl};

    $sth->_dbix_l4p_debug('execute_array', @args)
      if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    if (($#args >= 0) && ($args[0]) &&
	    (ref($args[0]) eq 'HASH') &&
		(!exists($args[0]->{ArrayTupleStatus}))) {
	$args[0]->{ArrayTupleStatus} = \my @tuple_status;
    } elsif (!$args[0]) {
	$args[0] = {ArrayTupleStatus => \my @tuple_status};
    }
    my $array_tuple_status = $args[0]->{ArrayTupleStatus};

    #
    # NOTE: We have a problem here. The DBI pod stipulates that
    # execute_array returns undef (for error) or the number of tuples
    # executed. If we want to access the number of rows updated or
    # inserted then we need to add up the values in the ArrayTupleStatus.
    # Unfortunately, the drivers which implement execute_array themselves
    # (e.g. DBD::Oracle) don't do this properly (e.g. DBD::Oracle 1.18a).
    # As a result, until this is sorted out, our logging of execute_array
    # may be less than accurate.
    # NOTE: DBD::Oracle 1.19 is working now from my supplied patch
    #
    my ($executed, $affected) = $sth->SUPER::execute_array(@args);
    if (!$executed) {
        #print Data::Dumper->Dump([$sth->{ParamArrays}], ['ParamArrays']), "\n";
	if (!$h->{logmask} & DBIX_L4P_LOG_ERRORS) {
	    return $executed unless wantarray;
	    return ($executed, $affected);
	}
        my $pa = $sth->{ParamArrays};
	$h->{logger}->error("execute_array error:");
	for my $n (0..@{$array_tuple_status}-1) {
	    next if (!ref($array_tuple_status->[$n]));
	    $sth->_dbix_l4p_error('Error', $array_tuple_status->[$n]);
	    my @plist;
	    foreach my $p (keys %{$pa}) {
	        if (ref($pa->{$p})) {
		    push @plist, $pa->{$p}->[$n];
		} else {
		    push @plist, $pa->{$p};
		}
	    }
	    $h->{logger}->error(sub {"\t for " .
				     join(',', map(DBI::neat($_), @plist))});
	}
    } elsif ($executed) {
	if ((defined($sth->{NUM_OF_FIELDS})) || # result-set
		!($h->{logmask} & DBIX_L4P_LOG_INPUT)) { # logging input
	    return $executed unless wantarray;
	    return ($executed, $affected);
	}
	$sth->_dbix_l4p_debug("executed $executed, affected " .
				  DBI::neat($affected));
    }
    $h->{logger}->info(sub {Data::Dumper->Dump(
	[$array_tuple_status], ['ArrayTupleStatus'])})
	if ($h->{logmask} & DBIX_L4P_LOG_INPUT);
    return $executed unless wantarray;
    return ($executed, $affected);
}

sub bind_param {
  my($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  $sth->_dbix_l4p_debug('bind_param', @args)
    if ($h->{logmask} & DBIX_L4P_LOG_INPUT);
  return $sth->SUPER::bind_param(@args);
}

sub bind_param_inout {
  my($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  $sth->_dbix_l4p_debug('bind_param_inout', @args)
    if (($h->{logmask} & DBIX_L4P_LOG_INPUT) &&
	(caller !~ /^DBD::/));
  return $sth->SUPER::bind_param_inout(@args);
}

sub bind_param_array {
  my($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  $sth->_dbix_l4p_debug('bind_param_array', @args)
    if ($h->{logmask} & DBIX_L4P_LOG_INPUT);
  return $sth->SUPER::bind_param_array(@args);
}

sub fetch {			# alias for fetchrow_arrayref
  my($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  my $res = $sth->SUPER::fetch(@args);
  $h->{logger}->debug(sub {Data::Dumper->Dump([$res], ['fetch'])})
    if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
  return $res;
}

sub fetchrow_arrayref {			# alias for fetchrow_arrayref
  my($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  my $res = $sth->SUPER::fetchrow_arrayref(@args);
  $h->{logger}->debug(sub {Data::Dumper->Dump([$res],
						   ['fetchrow_arrayref'])})
    if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
  return $res;
}

sub fetchrow_array {
  my ($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  my @row = $sth->SUPER::fetchrow_array(@args);
  $h->{logger}->debug(sub {
			     Data::Dumper->Dump([\@row], ['fetchrow_array'])})
    if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
  return @row;
}

sub fetchrow_hashref {
  my($sth, @args) = @_;
  my $h = $sth->{private_DBIx_Log4perl};

  my $res = $sth->SUPER::fetchrow_hashref(@args);
  $h->{logger}->debug(
      sub {Data::Dumper->Dump([$res], ['fetchrow_hashref'])})
    if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
  return $res;
}

1;
