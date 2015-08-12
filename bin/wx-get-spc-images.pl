#!/usr/bin/perl -wT

# wx-get-spc-images.pl - download SPC images for current mesoscale discussions and watch boxes
#                      because for some reason, the SPC website is unresponsive way too often.

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use Weather::Web;

my $dt = Utils::get_formatted_date_time(); 
    
my $imagedir = Config::get_value_for("imagedir");

my $md_img  = Config::get_value_for("spc_md_image_url");
my $box_img = Config::get_value_for("spc_watch_box_image_url");

my $stored_file = "";


# download the current mesoscale discussions image
    if ( $md_img =~ m /^.*[\/](.*)$/ ) {
        $stored_file = $imagedir . $1;
    } else {
        die "cannot obtain file name from $md_img.\n";
    }

    if ( $stored_file =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $stored_file = $1;
    } else {
        die "$dt : Bad data in first argument";	
    }

    my $ua = LWP::UserAgent->new;
        # $ua->timeout(180) # default is 180 secs or 3 mins   

    my $request = HTTP::Request->new( GET => $md_img);
    my $response = $ua->request($request);
    if ($response->is_success) {
        my $content = $response->content;
        open FILE, ">$stored_file" or die "Can't create file.\n";
        binmode FILE;
        if ($response->is_success){
            print FILE $content;
        }else{
            print STDERR "file not downloaded.\n";
        }
        close FILE;
    } 
    else {
        die $response->status_line;
    }


# download the current watch boxes image
    if ( $box_img =~ m /^.*[\/](.*)$/ ) {
        $stored_file = $imagedir . $1;
    } else {
        die "cannot obtain file name from $box_img.\n";
    }

    if ( $stored_file =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $stored_file = $1;
    } else {
        die "$dt : Bad data in first argument";	
    }

    $ua = LWP::UserAgent->new;
        # $ua->timeout(180) # default is 180 secs or 3 mins   

    $request = HTTP::Request->new( GET => $box_img);
    $response = $ua->request($request);
    if ($response->is_success) {
        my $content = $response->content;
        open FILE, ">$stored_file" or die "Can't create file.\n";
        binmode FILE;
        if ($response->is_success){
            print FILE $content;
        }else{
            print STDERR "file not downloaded.\n";
        }
        close FILE;
    } 
    else {
        die $response->status_line;
    }
