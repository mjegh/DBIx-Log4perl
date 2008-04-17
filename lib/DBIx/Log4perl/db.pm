# $Id: db.pm 245 2006-07-25 14:20:59Z martin $
use strict;
use warnings;
use DBI;
use Log::Log4perl;

package DBIx::Log4perl::db;
@DBIx::Log4perl::db::ISA = qw(DBI::db DBIx::Log4perl);
use DBIx::Log4perl::Constants qw (:masks $LogMask);

sub get_info
{
    my ($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    my $value = $dbh->SUPER::get_info(@args);

    $dbh->_dbix_l4p_debug(2, "get_info($h->{dbh_no})", @args, $value)
        if ($h->{logmask} & DBIX_L4P_LOG_INPUT);
}
sub prepare {
    my($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    my $ctr = $h->{new_stmt_no}(); # get a new unique stmt counter in this dbh
    if (($h->{logmask} & DBIX_L4P_LOG_INPUT) &&
            (caller !~ /^DBIx::Log4perl/) &&
                (caller !~ /^DBD::/)) { # e.g. from selectall_arrayref
        $dbh->_dbix_l4p_debug(2, "prepare($h->{dbh_no}.$ctr)", $args[0]);
    }

    my $sth = $dbh->SUPER::prepare(@args);
    if ($sth) {
        $sth->{private_DBIx_Log4perl} = $h;
        $sth->{private_DBIx_st_no} = $ctr;
    }

    return $sth;
}

sub prepare_cached {
    my($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    my $ctr = $h->{new_stmt_no}();
    if (($h->{logmask} & DBIX_L4P_LOG_INPUT) &&
            (caller !~ /^DBIx::Log4perl/) &&
                (caller !~ /^DBD::/)) { # e.g. from selectall_arrayref
        $dbh->_dbix_l4p_debug(2,
                              "prepare_cached($h->{dbh_no}.$ctr)", $args[0]);
    }

    my $sth = $dbh->SUPER::prepare_cached(@args);
    if ($sth) {
        $sth->{private_DBIx_Log4perl} = $h;
        $sth->{private_DBIx_st_no} = $ctr;
    }
    return $sth;
}

sub do {
    my ($dbh, @args) = @_;
    my $h = $dbh->{private_DBIx_Log4perl};

    $h->{Statement} = $args[0];
    $dbh->_dbix_l4p_debug(2, "do($h->{dbh_no})", @args)
        if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    my $affected = $dbh->SUPER::do(@args);

    if (!defined($affected)) {
        $dbh->_dbix_l4p_error(2, 'do error for ', @args)
            if (($h->{logmask} & DBIX_L4P_LOG_ERRCAPTURE) &&
                    !($h->{logmask} & DBIX_L4P_LOG_INPUT)); # not already logged
    } elsif (defined($affected) && $affected eq '0E0' &&
                 ($h->{logmask} & DBIX_L4P_LOG_WARNINGS)) {
        $dbh->_dbix_l4p_warning(2, 'no effect from ', @args);
    } elsif (($affected ne '0E0') && ($h->{logmask} & DBIX_L4P_LOG_INPUT)) {
        $dbh->_dbix_l4p_debug(2, "affected($h->{dbh_no})", $affected);
        $dbh->_dbix_l4p_debug(2, "\t" . $dbh->SUPER::errstr)
            if (!defined($affected));
    }
    return $affected;
}

sub selectrow_array {
    my ($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    $dbh->_dbix_l4p_debug(2, "selectrow_array($h->{dbh_no})", @args)
      if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    if (wantarray) {
	my @ret = $dbh->SUPER::selectrow_array(@args);
	$dbh->_dbix_l4p_debug(2, 'result', @ret)
	  if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
	return @ret;

    } else {
	my $ret = $dbh->SUPER::selectrow_array(@args);
	$dbh->_dbix_l4p_debug(2, 'result', $ret)
	  if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
	return $ret;
    }
}

sub selectrow_arrayref {
    my ($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    $dbh->_dbix_l4p_debug(2, "selectrow_arrayref($h->{dbh_no})", @args)
      if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    my $ref = $dbh->SUPER::selectrow_arrayref(@args);
    $dbh->_dbix_l4p_debug(2, 'result', $ref)
      if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
    return $ref;
}

sub selectrow_hashref {
    my ($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};

    $dbh->_dbix_l4p_debug(2, "selectrow_hashref($h->{dbh_no})", @args)
        if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    my $ref = $dbh->SUPER::selectrow_hashref(@args);
    # no need to show result - fetch will do this
    return $ref;

}

sub selectall_arrayref {
    my ($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    $dbh->_dbix_l4p_debug(2, "selectall_arrayref($h->{dbh_no})", @args)
      if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    my $ref = $dbh->SUPER::selectall_arrayref(@args);
    $dbh->_dbix_l4p_debug(2, 'result', $ref)
      if ($h->{logmask} & DBIX_L4P_LOG_OUTPUT);
    return $ref;
}

sub selectall_hashref {
    my ($dbh, @args) = @_;

    my $h = $dbh->{private_DBIx_Log4perl};
    $dbh->_dbix_l4p_debug(2, "selectall_hashref($h->{dbh_no})", @args)
        if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    my $ref = $dbh->SUPER::selectall_hashref(@args);
    # no need to show result - fetch will do this
    return $ref;

}
sub disconnect {
    my $dbh = shift;

    if ($dbh) {
	my $h;
	eval {
	    # Avoid
	    # (in cleanup) Can't call method "FETCH" on an undefined value
	    $h = $dbh->{private_DBIx_Log4perl};
	};
	if (!$@ && $h && defined($h->{logger})) {
            if ($h->{logmask} & DBIX_L4P_LOG_CONNECT) {
                local $Log::Log4perl::caller_depth =
                    $Log::Log4perl::caller_depth + 2;
                $dbh->_dbix_l4p_debug(2, "disconnect($h->{dbh_no})");
            }
	}
    }
    return $dbh->SUPER::disconnect;
    
}

sub begin_work {
    my $dbh = shift;
    my $h = $dbh->{private_DBIx_Log4perl};

    $dbh->_dbix_l4p_debug(2, "start transaction($h->{dbh_no})")
        if ($h->{logmask} & DBIX_L4P_LOG_TXN);

    return $dbh->SUPER::begin_work;
}

sub rollback {
    my $dbh = shift;
    my $h = $dbh->{private_DBIx_Log4perl};

    $dbh->_dbix_l4p_debug(2, "roll back($h->{dbh_no})")
        if ($h->{logmask} & DBIX_L4P_LOG_TXN);

    return $dbh->SUPER::rollback;
}
  
sub commit {
    my $dbh = shift;

    my $h = $dbh->{private_DBIx_Log4perl};
    $dbh->_dbix_l4p_debug(2, "commit($h->{dbh_no})")
        if ($h->{logmask} & DBIX_L4P_LOG_TXN);

    return $dbh->SUPER::commit;
}

sub last_insert_id {
    my ($dbh, @args) = @_;
    my $h = $dbh->{private_DBIx_Log4perl};

    $dbh->_dbix_l4p_debug(
	sub {Data::Dumper->Dump([\@args], ["last_insert_id($h->{dbh_no})"])})
      if ($h->{logmask} & DBIX_L4P_LOG_INPUT);

    my $ret = $dbh->SUPER::last_insert_id(@args);
    $dbh->_dbix_l4p_debug(sub {"\t" . DBI::neat($ret)})
      if ($h->{logmask} & DBIX_L4P_LOG_INPUT);
    return $ret;
}
1;
