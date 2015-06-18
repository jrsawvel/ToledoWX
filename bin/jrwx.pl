#!/usr/bin/perl -wT

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/ToledoWX/lib";
}


use JSON::PP;
use XML::TreePP;
use LWP::Simple;
use LWP::UserAgent;
use XML::FeedPP;
use Time::Local;
use Data::Dumper;

my @alerts  = get_alerts();
my @md      = get_mesoscale_info();
my @hazards = get_hazards();

create_rss(\@alerts, \@md, \@hazards);



sub get_mesoscale_info {

    my @array = ();
    
    # reference to an array of hasshes
    # for testing my $mdtree = read_and_parse_xml_file("http://toledotalk.com/spcmdrss.xml");
    my $mdtree = read_and_parse_xml_file("http://www.spc.noaa.gov/products/spcmdrss.xml");

    my $mdarrref = $mdtree->{'rss'}->{'channel'}->{'item'};
    if ( ref $mdarrref eq ref [] ) {
        foreach my $mditem ( @$mdarrref ) {
            my %hash = process_md_hash_ref($mditem);
            push(@array, \%hash) if %hash;
        }
    }  else {
            my %hash = process_md_hash_ref($mdarrref);
            push(@array, \%hash) if %hash;
    }

    return @array;
}


sub process_md_hash_ref {
    my $mditem = shift;

    my %mdhash = ();
    my $mdtitle = $mditem->{'title'};
    my $mdlink = $mditem->{'link'};
    my $mdpubdate = $mditem->{'pubDate'};
    my $mddesc = $mditem->{'description'};

    if ( regional_md($mddesc) ) {
        $mdhash{'title'}= $mdtitle;
        $mdhash{'link'}= $mdlink;
        $mdhash{'pubDate'}= $mdpubdate;
    } 

    return %mdhash;
}


# attn...wfo...
# if (  $mddesc =~ m/CLE/s   or  $mddesc =~ m/DTX/s  or  $mddesc =~ m/IWX/s  ) {
sub regional_md {
    my $str = shift;
    my $return_val = 0;

    if ( $str =~ m/attn(.*)wfo(.*)/is ) {
        my $tmp_str = $2;
        if (  $tmp_str =~ m/CLE/s   or  $tmp_str =~ m/DTX/s  or  $tmp_str =~ m/IWX/s  ) {
            $return_val = 1;
        }
    }    

    return $return_val;
}

sub read_and_parse_xml_file {
    my $xml_url = shift;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($xml_url);
    if ( $response->is_error ) {
       die "could not retrieve $xml_url. " . $response->status_line; 
    }

    my $result;
    my $tree = "";

    $result = eval {
        my $content = $response->content;
        my $tpp = XML::TreePP->new();
        $tree = $tpp->parse($content);
    };

    unless ($result) {
        die "could not parse $xml_url."; 
    }

    if ( !$tree ) {
        die "could not parse $xml_url."; 
    }

    return $tree;
}


sub get_alerts {
    my @array = ();

    my $xml = "http://alerts.weather.gov/cap/wwaatmget.php?x=OHC095&y=0";
    
    my $feed = XML::FeedPP->new($xml);

    die "could not retrieve feed $xml" if !$feed;

    foreach my $item ( $feed->get_item() ) {
        my %hash;
        $hash{'link'}  = $item->link();
        # $hash{'title'} = $item->title();
        $hash{'title'} = $item->get("cap:event");
        # $hash{'desc'}  = $item->description();
        $hash{'pubDate'}  = reformat_nws_date_time($item->pubDate());
        push(@array, \%hash); 
    }

    return @array;
}

sub get_hazards {
  
    my @array = ();

    my $json_hash_ref = read_and_parse_json_file();

    my $hazard_text_array = $json_hash_ref->{'data'}->{'hazard'};
    my $hazard_url_array  = $json_hash_ref->{'data'}->{'hazardUrl'};
    my $array_len = @$hazard_text_array;

    for (my $i=0; $i<$array_len; $i++) {
        my %hash;

        my $hazard  = $hazard_text_array->[$i]; 
        if ( $hazard eq "Hazardous Weather Outlook" ) {
            $hash{'title'}  = $hazard;
            $hash{'link'}   = $hazard_url_array->[$i];
            $hash{'pubDate'}  = "";
            push(@array, \%hash); 
        }
    }

    return @array;
}

sub read_and_parse_json_file {

    my $json_url = "http://forecast.weather.gov/MapClick.php?lat=41.61000&lon=-83.8&unit=0&lg=english&FcstType=json";

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($json_url);
    if ( $response->is_error ) {
       die "could not retrieve $json_url. " . $response->status_line; 
    }

    my $result;
    my $tree = "";

    $result = eval {
        my $content = $response->content;
        $tree = decode_json $content;
    };

    unless ($result) {
        die "could not parse $json_url."; 
    }

    if ( !$tree ) {
        die "could not parse $json_url."; 
    }

    return $tree;
}



sub create_rss {
    # array refs to hash refs
    my $alerts  = shift;
    my $md      = shift;
    my $hazards = shift;

    my $pub_date = create_date_time_stamp();


    my $rss = <<EORSS1;
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:rss5="http://rss5.org/">
  <channel>
   <title>Toledo Weather Messages</title>
   <link>http://toledotalk.com/weather</link>
   <description>Watches, Warnings, Advisories, Discussions</description>
   <pubDate>$pub_date</pubDate>
   <language>en-us</language>
   <generator>jrwx.pl</generator>
   <docs>http://cyber.law.harvard.edu/rss/rss.html</docs>
EORSS1

    print $rss;

   if ( $alerts ) {
    foreach my $hash_ref ( @$alerts ) {
        print "    <item>\n";
        print "     <title>$hash_ref->{'title'}</title>\n";
        print "     <description>$hash_ref->{'title'}</description>\n";
        print "     <pubDate>$hash_ref->{'pubDate'}</pubDate>\n";
        print "     <guid>$hash_ref->{'link'}</guid>\n";
        print "     <link>$hash_ref->{'link'}</link>\n";
        print "     <author>Cleveland National Weather Service</author>\n";
        print "    </item>\n";
    }
  }

   if ( $md ) {
    foreach my $hash_ref ( @$md ) {
        print "    <item>\n";
        print "     <title>$hash_ref->{'title'}</title>\n";
        print "     <description>$hash_ref->{'title'}</description>\n";
        print "     <pubDate>$hash_ref->{'pubDate'}</pubDate>\n";
        print "     <guid>$hash_ref->{'link'}</guid>\n";
        print "     <link>$hash_ref->{'link'}</link>\n";
        print "     <author>Storm Prediction Center</author>\n";
        print "    </item>\n";
    }
  }

   if ( $hazards ) {
    foreach my $hash_ref ( @$hazards ) {
        print "    <item>\n";
        print "     <title>$hash_ref->{'title'}</title>\n";
        print "     <description>$hash_ref->{'title'}</description>\n";
#        print "     <pubDate>$hash_ref->{'pubDate'}</pubDate>\n";
        print "     <pubDate>$pub_date</pubDate>\n";
        print "     <guid>$hash_ref->{'link'}</guid>\n";
        print "     <link>$hash_ref->{'link'}</link>\n";
        print "     <author>Cleveland National Weather Service</author>\n";
        print "    </item>\n";
    }
  }

    print "  </channel>\n</rss>\n";

}

# create date-time stamp as: Thu, 18 Jun 2015 11:41:07 GMT
#           another example: Wed, 02 Oct 2002 13:00:00 GMT
#                          : Wed, 02 Oct 2002 15:00:00 +0200
sub create_date_time_stamp {

    my @month_names = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my @day_names   = qw(Sun Mon Tue Wed Thu Fri Sat);

    my $epochsecs = time();

    my ($sec, $min, $hr, $d, $m, $y, $wd)  = (gmtime($epochsecs))[0,1,2,3,4,5,6];

    my $datetime = sprintf "%s, %02d %s %04d %02d:%02d:%02d GMT", $day_names[$wd], $d, $month_names[$m], 2000 + $y-100, $hr, $min, $sec;

   return $datetime;
}

# convert this 2013-06-23T11:52:00-04:00 into: 18 Jun 2015 06:23:45 -0400
# the weekday name will be missing from the resulting string.
# the weekday name appears to be optional in the RSS spec.
# http://www.w3.org/Protocols/rfc822/#z28
sub reformat_nws_date_time {
    my $nws_date_time_str = shift;
    
    if ( !$nws_date_time_str ) {
        return "";
    }

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my @values = split('T', $nws_date_time_str);

    # work on time first
    my @hrminsec = split('-', $values[1]);
    my @time = split(':', $hrminsec[0]);
    my $hr = $time[0];
    my $min = $time[1];
    my $sec = $time[2];

    my $time_str = sprintf("%02d:%02d:%02d -%s", $hr, $min, $sec, $hrminsec[1]); 

    # work on date
    my @yrmonday = split('-', $values[0]);
    my $date_str = sprintf("%02d %s %d", $yrmonday[2], $months[$yrmonday[1]-1], $yrmonday[0]);

    return $date_str . " " . $time_str;
}


