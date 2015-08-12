#!/usr/bin/perl -wT

# wx-create-index-page.pl - create the home page

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledoweather/ToledoWX/lib";
}

use JSON::PP;
use Weather::Web;
use Weather::DateTimeFormatter;
use Data::Dumper;
use HTML::Entities;

my $current_date_time = Utils::get_formatted_date_time(); 
my $html_output_filename =  Config::get_value_for("htmldir") . Config::get_value_for("wx_index_output_file");
if ( $html_output_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
    $html_output_filename = $1;
} else {
    die "$current_date_time : Bad filename $html_output_filename."; 
}

my $hazardous_outlook_exists = 0;

my $discussion_url = Config::get_value_for("forecast_discussion");
my $discussion_text = LWP::Simple::get($discussion_url);  
die "$current_date_time : Could not retrieve $discussion_url" unless $discussion_text;
my $discussion_time = "";
$discussion_text = lc($discussion_text);
if ( $discussion_text =~ m/^(.*)est(.*)$/m ) {
    $discussion_time = $1; 
    $discussion_time = Utils::reformat_nws_text_time($discussion_time);
}

my $marine_url = Config::get_value_for("marine_forecast");
my $marine_text = LWP::Simple::get($marine_url);  
die "$current_date_time : Could not retrieve $marine_url" unless $marine_text;
my $marine_time = "";
$marine_text = lc($marine_text);
if ( $marine_text =~ m/^(.*)est(.*)$/m ) {
    $marine_time = $1; 
    $marine_time = Utils::reformat_nws_text_time($marine_time);
}

my $tree = read_and_parse_xml_file("lucas_county_zone_xml");

my %conditions = ();
$conditions{updatedate} = $tree->{'dwml'}->{'data'}->[1]->{'time-layout'}->{'start-valid-time'}->{'#text'};
$conditions{weather} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'weather'}->{'weather-conditions'}->[0]->{'-weather-summary'};
$conditions{temperature} = $tree->{'dwml'}->{'data'}->[1]->{'parameters'}->{'temperature'}->[0]->{'value'};
my %conditions_dt = Utils::reformat_nws_date_time($conditions{updatedate});
$conditions{updatedate} = $conditions_dt{time} . $conditions_dt{period};

my $forecast_creation_date = $tree->{'dwml'}->{'head'}->{'product'}->{'creation-date'}->{'#text'};
my %forecast_dt = Utils::reformat_nws_date_time($forecast_creation_date);
$forecast_creation_date = $forecast_dt{time} . $forecast_dt{period};



# grabbing alert messages
# switched to json file on 10June2014
my $alert_msg = "";

# reference to an array of hashes - possibly unless only one hazard message exists and then it's not an array.
my $json_tree = read_and_parse_json_file("lucas_county_zone_json");

# print Dumper $json_tree;

my $hazard_text_array = $json_tree->{'data'}->{'hazard'};
my $hazard_url_array  = $json_tree->{'data'}->{'hazardUrl'};
my $array_len = @$hazard_text_array;

my %alerts = ();

for (my $i=0; $i<$array_len; $i++) {
    my $hazard     = lc($hazard_text_array->[$i]); 
    my $hazard_url = $hazard_url_array->[$i];
    if ( $hazard eq "hazardous weather outlook" ) {
        $hazardous_outlook_exists = 1;
    }
    $alerts{$hazard} = $hazard_url;
}


my $hazardous_outlook_time = "";

my $txt_url = Config::get_value_for("hazardous_outlook");
my $text = LWP::Simple::get($txt_url);  
die "$current_date_time : Could not retrieve $txt_url" unless $text;
$text = lc($text);
if ( $text =~ m/^(.*)est(.*)$/m ) {
    $hazardous_outlook_time = $1; 
}


my @alert_button_loop;
my @alert_rss_loop;

my $alert_buttons_exist = 0;

foreach my $key ( keys %alerts )
{
    my %button_hash = ();
    my %rss_hash = ();

    my $x_txt_url = decode_entities($alerts{$key});
    my $x_text = LWP::Simple::get($x_txt_url);  
    die "$current_date_time : Could not retrieve $x_txt_url" unless $text;
    $x_text = lc($x_text);

    my $msg = "";
    if ( $x_text =~ m/<h3>$key<\/h3><pre>(.*)<\/pre><hr \/><br \/><h3>/is ) {
        $msg = $1;
    } elsif ( $x_text =~ m/<h3>$key<\/h3><pre>(.*)<\/pre><hr \/><br \/>/is ) {
        $msg = $1;
    } elsif ( $x_text =~ m/<h3>$key<\/h3><pre>(.*)<\/pre><hr\/><br\/>/is ) {
        $msg = $1;
    } else {
        die "$current_date_time : could not parse file. $x_text \n";
    }    

    my $alert_time = "";
    my $alert_date = "";
    my $orig_alert_time = "";
    if ( $msg =~ m/^(.*)est(.*)$/m ) {
        $alert_time = $1; 
        $alert_time = Utils::reformat_nws_text_time($alert_time);

        $orig_alert_time = $1; 
        $alert_date = $2; 
    }

    if ( $key eq "hazardous weather outlook" and $msg =~ m/(.*)lez061(.*)this hazardous weather outlook is(.*)/s ) {
        $msg = $1 . "<br />" .  $3;
    }

    $msg = Utils::remove_html($msg);
    $msg = Utils::trim_spaces($msg);
    $msg = Utils::newline_to_br($msg);

    my $filename = $key;
    $filename =~ s/ /-/g;
    $filename = $filename . ".html";
    my $filepath = Config::get_value_for("htmldir") . $filename; 
    if ( $filepath =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $filepath = $1;
    } else {
        die "$current_date_time : Bad filename $filepath."; 
    }

    Web::set_template_name("specialstatement");
    Web::set_template_variable("msg", $msg);
    my $html_output = Web::display_page("$key", "returnoutput");

    open FILE, ">$filepath" or die "$current_date_time : Can't create file.";
    print FILE $html_output;
    close FILE;

    $button_hash{alert} = Utils::ucfirst_each_word($key);
    $rss_hash{alert}    = Utils::ucfirst_each_word($key);

    $button_hash{url}        = $filename;
    $rss_hash{url}           = $filename;

    $button_hash{alert_time} = $alert_time;
    $rss_hash{alert_date}    = _reformat_date($alert_date);
    $rss_hash{alert_time}    = _reformat_time($alert_time);

    $button_hash{wxhome}     = Config::get_value_for("wxhome");
    $rss_hash{wxhome}        = Config::get_value_for("wxhome");

    push(@alert_button_loop, \%button_hash);
    push(@alert_rss_loop, \%rss_hash);

    $alert_buttons_exist = 1;
}

my @meso_loop = get_mesoscale_info();

output_rss_file(\@alert_rss_loop);


Web::set_template_name("wxindex");

Web::set_template_variable("refresh_button", 1);
Web::set_template_variable("refresh_button_url", Config::get_value_for("home_page")); 

Web::set_template_variable("hazardous_outlook_exists", $hazardous_outlook_exists);
Web::set_template_variable("hazardous_outlook_time", $hazardous_outlook_time);

my @reversed_alert_button_loop = reverse @alert_button_loop;

Web::set_template_loop_data("buttonalerts" , \@reversed_alert_button_loop);

Web::set_template_variable("conditions_time",        $conditions{updatedate});
Web::set_template_variable("conditions_weather",     $conditions{weather});
Web::set_template_variable("conditions_temperature", $conditions{temperature});

Web::set_template_variable("forecast_time", $forecast_creation_date);

Web::set_template_variable("discussion_time", $discussion_time);

Web::set_template_variable("marine_time", $marine_time);

Web::set_template_variable("wxhome",    Config::get_value_for("wxhome"));

Web::set_template_loop_data("mesoscale" , \@meso_loop) if @meso_loop;

my $html_output = Web::display_page("Toledo Weather", "returnoutput");

open FILE, ">$html_output_filename" or die "$current_date_time : could not create file $html_output_filename";
print FILE $html_output;
close FILE;



sub output_rss_file {
    my $alerts = shift;

    my @alert_button_loop = reverse (@$alerts);

    # Wed, 06 Aug 2014 11:52:01 GMT
    my $pub_date = DateTimeFormatter::create_date_time_stamp_utc("(dayname), (0daynum) (monthname) (yearfull) (012hr):(0min):(0sec)") . " GMT";

    Web::set_template_name("wx-alerts-rss");
    Web::set_template_variable("pub_date", $pub_date);
    Web::set_template_loop_data("alerts" , \@alert_button_loop);
    my $rss_output = Web::display_rss_page("Toledo Weather Alert RSS", "returnoutput");

    my $rss_output_filename =  Config::get_value_for("htmldir") . "alerts.rss";
    if ( $rss_output_filename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $rss_output_filename = $1;
    } else {
        die "$current_date_time : Bad filename $rss_output_filename."; 
    }

    open FILE, ">$rss_output_filename" or die "$current_date_time : could not create file $rss_output_filename";
    print FILE $rss_output;
    close FILE;
}

sub get_mesoscale_info {

    my @array = ();
    
    # reference to an array of hasshes
    my $mdtree = read_and_parse_xml_file("spc_md_xml");

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

    my $wxhome = Config::get_value_for("wxhome");
 
            my %hash = ();
            my %mdhash = ();
            my $content;
            my $link;
            my $mdnum = 0;
            my $mdtime;
            my $mdlink = $mditem->{'link'};
            my $mddesc = $mditem->{'description'};

            if ( regional_md($mddesc) ) {
                $link = $mdlink;
                $content = $mddesc;
                $content = Utils::remove_html($content);
                $content = Utils::trim_spaces($content);
                $content = lc($content);
                if ( $content =~ m/^(.*)est(.*)$/m ) {
                    $mdtime = $1; 
                    $mdtime = Utils::reformat_nws_text_time($mdtime);
                } elsif ( $content =~ m/^(.*)cst(.*)$/m ) {
                    $mdtime = $1; 
                    $mdtime = Utils::reformat_nws_text_time($mdtime, "cst");
                }
                $content = Utils::newline_to_br($content);

                my $htmldir = Config::get_value_for("htmldir");

                if ( $link =~ m/\/md\/md(.*)\.html/ ) {
                    $mdnum = $1;
                }
        
                $mdhash{mdcontent} = $content;
                $mdhash{mdfilename} = $htmldir . "mesoscale" . $mdnum . ".html";
                if ( $mdhash{mdfilename} =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
                    $mdhash{mdfilename} = $1;
                } else {
                    die "$current_date_time : Bad filename $mdhash{mdfilename}."; 
                }

                $mdhash{mdnum} = $mdnum;
                $mdhash{mdtime} = $mdtime;

                $hash{mdnum} = $mdnum;
                $hash{mdtime} = $mdtime;

                $hash{wxhome} = $wxhome;

                create_mesoscale_file(\%mdhash); 
            } 

    return %hash;
}


sub create_mesoscale_file {
    my $hash_ref = shift;

    my $mddt = Utils::get_formatted_date_time(); 

    my $gif_file = "mcd" . $hash_ref->{mdnum} . ".gif";
    download_gif($gif_file);

    my $img = "<img src=\"" .  Config::get_value_for("imagehome") . "/" . $gif_file . "\">";

    $hash_ref->{mdcontent} = $img . "<br />" . $hash_ref->{mdcontent};
   
    Web::set_template_name("mesoscale");
    Web::set_template_variable("content", $hash_ref->{mdcontent});
    my $html_output = Web::display_page("Mesoscale Discussion", "returnoutput");

    open FILE, ">$hash_ref->{mdfilename}" or die "$mddt : Can't create file.";
    print FILE $html_output;
    close FILE;
}

sub download_gif {
    my $gif_file = shift;
    my $error_out = shift;

    my $imagedir = Config::get_value_for("imagedir");

    my $mddt = Utils::get_formatted_date_time(); 

    my $spc_gif_url = Config::get_value_for("spcmesoscalegifhome") . "/" . $gif_file; 
    my $dayfilename = $imagedir . $gif_file;
    if ( $dayfilename =~  m/^([a-zA-Z0-9\/\.\-_]+)$/ ) {
        $dayfilename = $1;
    } else {
        die "$mddt : Bad filename $dayfilename."; 
    }
    my $gif_ua = LWP::UserAgent->new;
    my $gif_request = HTTP::Request->new( GET => $spc_gif_url);
    my $gif_response = $gif_ua->request($gif_request);
    if ($gif_response->is_success) {
        my $gif_content = $gif_response->content;
        open FILE, ">$dayfilename" or die "$mddt : Can't create file.";
        binmode FILE;
        print FILE $gif_content;
        close FILE;
    } elsif ( $error_out and $error_out eq "die" ) {
        die "$mddt : file not downloaded.";
    }
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
    my $str = shift;

    my $xml_url = Config::get_value_for($str);

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($xml_url);
    if ( $response->is_error ) {
       die "$current_date_time : could not retrieve $xml_url. " . $response->status_line; 
    }

    my $result;
    my $tree = "";

    $result = eval {
        my $content = $response->content;
        my $tpp = XML::TreePP->new();
        $tree = $tpp->parse($content);
    };

    unless ($result) {
        die "$current_date_time : could not parse $xml_url."; 
    }

    if ( !$tree ) {
        die "$current_date_time : could not parse $xml_url."; 
    }

    return $tree;
}

sub read_and_parse_json_file {
    my $str = shift;

    my $json_url = Config::get_value_for($str);

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30); 
    my $response = $ua->get($json_url);
    if ( $response->is_error ) {
       die "$current_date_time : could not retrieve $json_url. " . $response->status_line; 
    }

    my $result;
    my $tree = "";

    $result = eval {
        my $content = $response->content;
        $tree = decode_json $content;
    };

    unless ($result) {
        die "$current_date_time : could not parse $json_url."; 
    }

    if ( !$tree ) {
        die "$current_date_time : could not parse $json_url."; 
    }

    return $tree;
}

# have tue aug 5 2014 751 am 
# have tue aug 5 2014 7:51 am 
# need Aug 5, 2014 07:51:01
#
sub _reformat_date {
    my $alert_date = shift;

    $alert_date = Utils::trim_spaces($alert_date);

    my @dt = split(' ', $alert_date);

    my $dayname = ucfirst($dt[0]);

    my $mon = ucfirst($dt[1]);

    my $daynum = sprintf "%02d", $dt[2];

    my $year = $dt[3];

    return "$dayname, $daynum $mon $year";
}

sub _reformat_time {
    my $alert_time = shift;

    $alert_time = Utils::trim_spaces($alert_time);
    $alert_time =~ s/am//ig;
    $alert_time =~ s/pm//ig;

    my @t = split(':', $alert_time);

    my $hr  = sprintf "%02d", $t[0];
    my $min = $t[1];

    return "$hr:$min:01 GMT";
}

    # pubDate format: Tue, 04 Oct 2005 12:52:43 Z

