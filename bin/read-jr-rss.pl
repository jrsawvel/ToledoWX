#!/usr/bin/perl -wT

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/ToledoWX/lib";
}

use XML::FeedPP;
use Data::Dumper;

my $tt_alert_link = "<a title=\"Toledo Talk Weather Page\" href=\"http://toledotalk.com/weather/html/wx.html\">>></a>";
my $small_screen_link = "<div id=\"weatheralertssmall\"><a href=\"http://toledotalk.com/weather\">weather message >></a></div>";

my @msg = get_alerts();

my $len = @msg;

my $have_something = 0;

my $str;

if ( $len ) {
    foreach my $item (@msg) {
        if ( $item->{'link'} and $item->{'title'} ) {
            if ( $have_something ) {
                $str .= " - <a href=\"$item->{'link'}\">$item->{'title'}</a>";
            } else {
                $str .= "<a href=\"$item->{'link'}\">$item->{'title'}</a>";
            } 
            $have_something = 1;
        }
    }
}

if ( $have_something ) {
    $str =  "<div id=\"weatheralertswhite\">"  . $str . " - " . $tt_alert_link . "</div>" . $small_screen_link ;
    print $str;
} else {
    print "\n";
}

sub get_alerts {
    my @array = ();

    my $xml = "http://toledotalk.com/jr.rss";
    
    my $feed = XML::FeedPP->new($xml);

    die "could not retrieve feed $xml" if !$feed;

    foreach my $item ( $feed->get_item() ) {
        my %hash;
        $hash{'link'}  = $item->link();
        # $hash{'title'} = $item->title();
        $hash{'title'} = $item->title();
        # $hash{'desc'}  = $item->description();
        $hash{'pubDate'}  = $item->pubDate();
        push(@array, \%hash); 
    }
 
    return @array;
}

