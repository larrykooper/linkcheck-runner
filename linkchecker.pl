#!/usr/bin/perl -w
# w means turn on warnings
# http://cpan.uwinnipeg.ca/htdocs/DBI/DBI.html  
# Connect to database

use DBI;
use LWP;
 
my $response;
my $message;
my $httpcode;
my $redirectLocation;
my $browser = LWP::UserAgent->new;
$browser->requests_redirectable([]);  # do not follow redirects 
 
# $dbh is the database handle
# If your database is not hosted on localhost:
$dbh = DBI->connect('dbi:mysql:database-name;host=myhost.mydomain.com','user-name','password')
# If your database is on localhost:
$dbh = DBI->connect('dbi:mysql:database-name','user-name','password')

or die "Connection Error: $DBI::errstr\n";
# Done connecting to database
# Execute SQL statement
# $sql is the query
#   CHANGE THE FOLLOWING LINE 
$sql = "SELECT COUNT(*) FROM URL";
$sth = $dbh->prepare($sql);
$sth->execute;
$mycount = $sth->fetchrow_array;
print "count: $mycount\n";

$sql = "select URLID, URL from URL";
# $sth is the statement handler
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
# Done executing SQL statement 
# Iterate thru SQL results 
# Note -- fetchrow_array fetches the next row of data 
#  and returns it as a list (an array, in this case) containing the field values. 
#  Null fields are returned as undef values in the list
# @row is an array
my $done = 0;
while (@row = $sth->fetchrow_array) {   
    ($urlid, $url) = @row;
    print "URLID: $urlid\n";    
    my $TIMEOUT_IN_SECONDS = 5;
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm($TIMEOUT_IN_SECONDS);
        # this might time out
        $response = $browser->head($url);
        alarm(0);
    };

    # error number 4 is "Interrupted system call"
    if ($! == 4) {
        # WE HAD A TIMEOUT
        $message = 'Request timed out';
        $httpcode = '0';
        $redirectLocation = '';
    } else {
        # WE DID NOT TIME OUT
        $message = $response->status_line;
        $httpcode = $response->code;
        $redirectLocation = $response->header('location');
    }
    
    print "URL: $url\n";
    print "Message: ";
    print $message;
    print "\n";
    print "code: ";
    print $httpcode;
    print "\n";
    if (!defined $redirectLocation) {
        $redirectLocation = '';
    }
    print $redirectLocation;    
    print "\n";
    print "\n";
    $message=~ s/\'/\'\'/g;
    
    # BEGIN WRITE DB 
    
    $myUpdateQuery = "UPDATE URL SET LastChecked=NOW(), HttpCode='$httpcode', ErrorText='$message', RedirectLocation='$redirectLocation' WHERE URLID=$urlid";

    $dbh->do($myUpdateQuery);
    $done = $done + 1;
    print "Done with $done of $mycount\n";
    # END WRITE DB     
    
} 