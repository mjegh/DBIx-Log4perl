use strict;
use warnings;

package DBIx::Log4perl::Constants;
require Exporter;
our @ISA = qw(Exporter);

use constant DBIX_L4P_LOG_DEFAULT => 0x5d;
use constant DBIX_L4P_LOG_ALL => 0xffffff;
use constant DBIX_L4P_LOG_INPUT => 0x1;
use constant DBIX_L4P_LOG_OUTPUT => 0x2;
use constant DBIX_L4P_LOG_CONNECT => 0x4;
use constant DBIX_L4P_LOG_TXN => 0x8;
use constant DBIX_L4P_LOG_ERRCAPTURE => 0x10;
use constant DBIX_L4P_LOG_WARNINGS => 0x20;
use constant DBIX_L4P_LOG_ERRORS => 0x40;

our $LogMask = DBIX_L4P_LOG_DEFAULT;

our @EXPORT = ();
our @EXPORT_OK = qw ($LogMask);
our @EXPORT_MASKS = qw(DBIX_L4P_LOG_DEFAULT
		       DBIX_L4P_LOG_ALL
		       DBIX_L4P_LOG_INPUT
		       DBIX_L4P_LOG_OUTPUT
		       DBIX_L4P_LOG_CONNECT
		       DBIX_L4P_LOG_TXN
		       DBIX_L4P_LOG_ERRCAPTURE
		       DBIX_L4P_LOG_WARNINGS
		       DBIX_L4P_LOG_ERRORS
		     );
our %EXPORT_TAGS = (masks => \@EXPORT_MASKS);
Exporter::export_ok_tags('masks');


1;
