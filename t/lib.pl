# $Id$
use Cwd;
use File::Spec;

my $logtmp1;
my $logtmp2;

sub get_config
{
    my @v;
    if (-f ($file = "t/dbixl4p.config")  ||
	-f ($file = "../dbixl4p.config") ||
	-f ($file = "dbixl4p.config")) {
	open IN, "$file";
	while (<IN>) {
	    chomp;
	    if ($_ eq 'UNDEF') {
		push @v, undef;
	    } else {
		push @v, $_;
	    }
	}
    }
    return @v;
}
sub config
{
    open OUT, ">pipe.pl" or die "Failed to create pipe.pl - $!";
    print OUT "#!$^X\n";
    print OUT 'while (<STDIN>) {open OUT, ">>dbixl4p.log"; print OUT $_;close OUT;}';
    close OUT;
    chmod 0777, "pipe.pl";

    $logtmp1 = File::Spec->catfile(File::Spec->tmpdir, 'dbixroot.log');
    $logtmp2 = File::Spec->catfile(File::Spec->tmpdir, 'dbix.log');
    my $cwd = getcwd();
    my $pipe = File::Spec->catfile($cwd, "pipe.pl");
    my $loginit = qq(
log4perl.logger = FATAL, LOGFILE
   
# LOGFILE appender used by root (here)
# log anything at level ERROR and above to $logtmp1
log4perl.appender.LOGFILE=Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename=$pipe
log4perl.appender.LOGFILE.mode=pipe
log4perl.appender.LOGFILE.utf8=1
log4perl.appender.LOGFILE.autoflush=1
log4perl.appender.LOGFILE.Threshold = ERROR
log4perl.appender.LOGFILE.layout=PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern=[%r] %F %L %c - %m%n

# Define DBIx::Log4perl to output DEBUG and above msgs to
# $logtmp2 using the simple layout
log4perl.logger.DBIx.Log4perl=DEBUG, A1
log4perl.appender.A1=Log::Log4perl::Appender::File
log4perl.appender.A1.filename=$pipe
log4perl.appender.A1.mode=pipe
log4perl.appender.A1.utf8=1
log4perl.appender.A1.autoflush=1
log4perl.appender.A1.layout=Log::Log4perl::Layout::SimpleLayout
		     );

    ok (Log::Log4perl->init(\$loginit), 'init config');

    ok (Log::Log4perl->get_logger('DBIx::Log4perl'), 'get log handle');

}

sub check_log
{
    my $s = shift;
    $$s = "";
    return 0 if (! -r "dbixl4p.log");
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat("dbixl4p.log");
    return 0 if ($size <= 0);
    open IN, "<dbixl4p.log";
    while (<IN>) {$$s .= $_};
    close IN;
    unlink "dbixl4p.log";
    diag($$s) if ($ENV{TEST_VERBOSE});
    return 1;
}
1;
