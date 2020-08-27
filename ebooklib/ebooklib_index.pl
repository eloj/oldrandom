#!/usr/bin/perl -w
use strict;
use lib "../ebookrenamer";
use POSIX qw(strftime);

#
# Features needed:
#   Detect file already indexed (but not dupe), and detect file movement.
#   If 'parse' of filename of existing file gives different field values (not hash), what to do:
#      always update db with new info.
#      always keep old info, just report difference.
#      ask user.
#   
#
#
#

require "ebookfile.pm";

use DBI;
use Getopt::Long;
use Digest::SHA1 qw(sha1_hex);
use File::Find;
use File::Basename;
use Fcntl ':mode';
use Data::Dumper;
use POSIX 'strftime';

my $cfg = {
  'pgdb' => 'ebooklib',
  'pghost' => '',
  'pgport' => '5433',
  'pguser' => 'webuser',
  'pgpasswd' => '',

  'recurse' => 0,
  'rescan' => 0,
  'hash' => => 0,
  'basedir' => '/mnt/media3/books/',
  'workdir' => '.',
  'ignorewarnings' => 0,
  'maxlevel' => 0,
};

my $dbcache = {

};

sub cache_table($$$$$)
{
	my $cache = shift;
	my $table = shift;
	my $fields = shift;
	my $cols = shift;
	my $verbose = shift || 0;

	my $dbh = $cache->{'conf'}->{'dbh'};

	# Cache file formats
	my $col_aref = $dbh->selectcol_arrayref("SELECT ".join(',', @{$fields})." FROM ".$table, { Columns => \@$cols});
	my %col_href = @$col_aref;

	$cache->{'cache'}->{$table} = \%col_href;

	if ($verbose) {
			my $entries = scalar keys %col_href; 
			print "CACHE: ".$entries." ".$table." cached";
			print " (".join(',', keys %col_href).")" if ($entries > 0 && $entries < 15);
			print "\n";
	}
	return;
}

sub cache_has($$$$)
{
	my $cache = shift;
	my $bucket = shift;
	my $table = shift;
	my $key = shift;

	if (defined $cache &&
		defined $cache->{$bucket} && 
		defined $cache->{$bucket}->{$table}) {
		return (defined $cache->{$bucket}->{$table}->{$key} ? 1 : 0);
	}
	return 0;
}

sub cache_get($$$$)
{
	my $cache = shift;
	my $bucket = shift;
	my $table = shift;
	my $key = shift;

	if (cache_has($cache, $bucket, $table, $key)) {
		return $cache->{$bucket}->{$table}->{$key};
	}
	return undef;
}

sub cache_set($$$$$)
{
	my $cache = shift;
	my $bucket = shift;
	my $table = shift;
	my $key = shift;
	my $value = shift;

	print "CACHE: Adding $bucket->$table->$key = '$value'\n";

	$cache->{$bucket}->{$table}->{$key} = $value;
}

sub cache_set_many($$$$)
{
	my $cache = shift;
	my $bucket = shift;
	my $table = shift;
	my $data = shift;

	while((my $k,my $v) = each %{$data}) {
		$cache->{$bucket}->{$table}->{$k} = $v;
	}
}


sub has_cached($$$)
{
	my $cache = shift;
	my $table = shift;
	my $key = shift;

	return cache_has($cache, 'cache', $table, $key);
}

sub get_cached($$$)
{
	my $cache = shift;
	my $table = shift;
	my $key = shift;

	if (has_cached($cache, $table, $key)) {
		return $cache->{'cache'}->{$table}->{$key};
	}
	return undef;
}

sub add_to_cache($$$)
{
	my $cache = shift;
	my $table = shift;
	my $value = shift;

	if (has_cached($cache, $table, $value)) {
		print "Value '$value' already in table '$table', not added.\n";
		return 0;
	} else {
		#	print "CACHE: About to add $value to table $table\n";
	}

	# Add value to dbtable
	my $dbh = $cache->{'conf'}->{'dbh'};
	my $field = cache_get($cache, 'meta', $table, 'field');
	my $seq_id = cache_get($cache, 'meta', $table, 'seq');

#	$dbh->begin_work;
	my $q = "INSERT INTO ".$table."(".$field.") VALUES(?)";
	# print "QUERY: ".$q."\n";
	my $ins = $dbh->prepare($q);
	my $res = $ins->execute($value);

	#print "RESULT:";
	#print Dumper($res)."\n";

	# get insert id and update cache
	my $last_id = $dbh->last_insert_id(undef, undef, undef, undef, { sequence => $seq_id } );
	$dbh->commit or die $dbh->errstr;

	cache_set($cache, 'cache', $table, $value, $last_id);

	return $last_id;
}

sub populate_cache($$)
{
	my $dbh = shift;
	my $cache = shift;
	my $verbose = 1;

	$cache->{'conf'}->{'dbh'} = $dbh;

	cache_set_many($cache, 'meta', 'formats', {
		'field' => 'ext',
		'seq' => 'formats_format_id_seq'
	});
	cache_table($cache, 'formats', ['format_id', 'ext'], [2,1], $verbose);

	cache_set_many($cache, 'meta', 'publishers', {
		'field' => 'name',
		'seq' => 'publishers_publisher_id_seq'
	});
	cache_table($cache, 'publishers', ['publisher_id', 'name'], [2,1], $verbose);

	cache_set_many($cache, 'meta', 'paths', {
		'field' => 'path',
		'seq' => 'paths_path_id_seq'
	});
	cache_table($cache, 'paths', ['path_id', 'path'], [2,1], $verbose);
	return;
}




GetOptions(
	'pgdb=s' => \$cfg->{'pgdb'},
	'pghost=s' => \$cfg->{'pghost'},
	'pgport=s' => \$cfg->{'pgport'},
	'pguser=s' => \$cfg->{'pguser'},
	'pgpasswd=s' => \$cfg->{'pgpasswd'},
	'rescan!' => \$cfg->{'rescan'},
	'recurse!' => \$cfg->{'recurse'},
	'ignorewarnings!' => \$cfg->{'ignorewarnings'},
	'basedir=s' => \$cfg->{'basedir'},
	'maxlevel=n' => \$cfg->{'maxlevel'},
	'hash!' => \$cfg->{'hash'},
);

sub process_file
{
	my $reldir = $File::Find::dir;

	$reldir =~ s/^$cfg->{'basedir'}//;
	return if (substr($_, 0, 1) eq ".") || ($reldir =~ m/\/\..+$/);

	my $currlevel = 0;
	++$currlevel while $reldir =~ m/\//g;

	if ($currlevel > $cfg->{'maxlevel'}) {
			print "Exiting due to currlevel (=$currlevel) > maxlevel (".$cfg->{'maxlevel'}.") for '".$reldir."'\n";
			return;
	}

	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
		$atime,$mtime,$ctime,$blksize,$blocks) = lstat($_);
	
	if(S_ISDIR($mode)) {
			print "Ignoring directory '".$_."'\n";
			return;
	}

	my $date_added = POSIX::strftime("%Y-%m-%d %H:%M:%S",localtime $mtime);

#  print "Complete pathname: ".$File::Find::name."\n";

	# Here we have all the directory/file parts we want.
	my $filename = $_;
	#print "Base:'".$cfg->{'basedir'}."'\n";
	#print "Path:'".$reldir."', Filename '".$filename."'\n";

	my $cache = $dbcache;

	my $ext = '';
	if ($filename =~ m/[^.].+\.([^.]+)$/) {
			$ext = $1;
	}

	my $format_id;

	if (!has_cached($cache, 'formats', lc $ext)) {
		print "Not interesting format, ".$ext."\n";
		return;
	} else {
		$format_id = get_cached($cache, 'formats', lc $ext);
	}
	
    my $book = new ebookfile($filename);
	my $publisher = $book->publisher();

	if ($book->warnings() && !$cfg->{'ignorewarnings'}) {
        print "ebookfile '$filename' has warnings: ".join(", ", $book->warnings() )."\n";
		print "PARSED:\n";
		print "  title: ".$book->title()."\n";
		print "  publisher: ".$publisher."\n";
		print "  edition: ".$book->edition()."\n" if $book->edition();
		print "Add to database anyhow? [Y/n]: ";
		my $line = <STDIN>;
		chomp $line;
		if (! $line =~ m/^y(es)/i) {
			return;
		}
	}	

	if (!$publisher || $publisher =~ m/^[0-9]+/) {
		print "Setting unknown publisher for '$filename'\n";
		$publisher = 'unknown';
	}

	my $digest_sha1 = undef;
	if ($cfg->{'hash'}) {
		open FH, "<".$filename || die "Couldn't open file ".$!;
		print "Hashing file... ";
		my $hash_sha1 = Digest::SHA1->new;
		$hash_sha1->addfile(*FH);
		$digest_sha1 = $hash_sha1->hexdigest;
		print $digest_sha1."\n";
		close FH;
	}

	# if hash exists, then skip file.
#	my $book_file_exists = $dbh->do("SELECT 

	my $pub_id;
	if (!has_cached($cache, 'publishers', $publisher)) {
		$pub_id = add_to_cache($cache, 'publishers', $publisher);
	} else {
		$pub_id = get_cached($cache, 'publishers', $publisher);
	}

	my $dbh = $cache->{'conf'}->{'dbh'};

	my $ins_book = $dbh->prepare("INSERT INTO books(title,subtitle,edition,publisher_id) VALUES(?,?,?,?)");
	my $ins_file = $dbh->prepare("INSERT INTO files(book_id,format_id,path_base_id,path_id,file_size,file_hash_sha1,file_name,date_added,date_processed) VALUES (?,?,?,?,?,?,?,?,?)"); 

	my $title = $book->title();
	my $subtitle = "";
	if ($title =~ m/^([^-]+) - ([^-]+)/) {
		$title = $1;
		$subtitle = $2;
	}
	#	my $edition = ($book->edition ? $book->edition() : "");

	#	$dbh->begin_work;
	$ins_book->execute($title, $subtitle, $book->edition(), $pub_id) or die $ins_book->errstr;
	my $book_id = $dbh->last_insert_id(undef, undef, undef, undef, { sequence => 'books_book_id_seq' } );

	my $proc_date = strftime('%Y-%m-%d %H:%M:%S', localtime);

	print "Adding '".$filename."' ".(defined $digest_sha1 ? " with hash ".$digest_sha1 : "")."\n";
	#  print "Base:'".$cfg->{'basedir'}."'\n";
	my $path_id;
	my $path_base_id;
	if (!has_cached($cache, 'paths', $reldir)) {
		$path_id = add_to_cache($cache, 'paths', $reldir);
	} else {
		$path_id = get_cached($cache, 'paths', $reldir);
	}

	# XXX (move out) if not base in paths, add it.
	if (!has_cached($cache, 'paths', $cfg->{'basedir'})) {
		$path_base_id = add_to_cache($cache, 'paths', $cfg->{'basedir'});
	} else {
		$path_base_id = get_cached($cache, 'paths', $cfg->{'basedir'});
	}

	$ins_file->execute($book_id,$format_id,$path_base_id,$path_id,$size,$digest_sha1,$filename,$date_added,$proc_date) or die $ins_file->errstr;
	
	$dbh->commit or die $dbh->errstr;

}



if(@ARGV > 0) {
	$cfg->{'workdir'} = $ARGV[0];
} elsif (!$cfg->{'workdir'}) {
	die("Must supply basedir and workdir.");
}

my $dbh = DBI->connect("dbi:Pg:dbname=".$cfg->{'pgdb'}.
	($cfg->{'pghost'} ? ";host=".$cfg->{'pghost'} : "").
	($cfg->{'pgport'} ? ";port=".$cfg->{'pgport'} : ""),
	$cfg->{'pguser'}, $cfg->{'pgpasswd'}, {
		PrintError => 1,
		AutoCommit => 0
	}
) or die "Can not connect to database: ".$DBI::errstr."\n";

print "Connected to database '".$cfg->{'pgdb'}."'.\n";

populate_cache($dbh,$dbcache);

# exit;

print "Processing '".$cfg->{'workdir'}."' with basedir:=".$cfg->{'basedir'}.", maxlevel:=".$cfg->{'maxlevel'}."\n";

finddepth( { 'wanted' => \&process_file } , ( $cfg->{'workdir'} ));


$dbh->disconnect;
print "Disconnected from database.\n";

