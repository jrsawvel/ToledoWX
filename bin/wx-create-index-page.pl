#!/usr/bin/perl -wT

# wx-create-index-page.pl - create the home page

use strict;

$|++;

BEGIN {
    unshift @INC, "/home/toledotk/Weather/lib";
}

use Weather::Web;
use Data::Dumper;

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
if ( $discussion_text =~ m/^(.*)edt(.*)$/m ) {
    $discussion_time = $1; 
    $discussion_time = Utils::reformat_nws_text_time($discussion_time);
}

my $marine_url = Config::get_value_for("marine_forecast");
my $marine_text = LWP::Simple::get($marine_url);  
die "$current_date_time : Could not retrieve $marine_url" unless $marine_text;
my $marine_time = "";
$marine_text = lc($marine_text);
if ( $marine_text =~ m/^(.*)edt(.*)$/m ) {
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

my $alert_msg = "";

# reference to an array of hashes - possibly unless only one hazard message exists and then it's not an array.
my $test = $tree->{'dwml'}->{'data'}->[0]->{'parameters'}->{'hazards'};

my %alerts = ();

if ( ref $test ne ref [] ) {
    my $hazard_headline_one = lc($tree->{'dwml'}->{'data'}->[0]->{'parameters'}->{'hazards'}->{'hazard-conditions'}->{'hazard'}->{'-headline'});
    my $hazard_url_one      = $tree->{'dwml'}->{'data'}->[0]->{'parameters'}->{'hazards'}->{'hazard-conditions'}->{'hazard'}->{'hazardTextURL'};
    if ( $hazard_headline_one and $hazard_url_one ) {
        if ( $hazard_headline_one eq "hazardous weather outlook" ) {
            $hazardous_outlook_exists = 1;
        }
        $alerts{$hazard_headline_one} = $hazard_url_one;
    }
} else {

    # looping through the reference to the array of hashes
    foreach my $hz ( @$test ) {
        # each hz in the loop is a hash
        my $hazard     = lc($hz->{'hazard-conditions'}->{'hazard'}->{'-headline'}); 
        my $hazard_url = $hz->{'hazard-conditions'}->{'hazard'}->{'hazardTextURL'};

        if ( $hazard eq "hazardous weather outlook" ) {
            $hazardous_outlook_exists = 1;
        }
        $alerts{$hazard} = $hazard_url;
    }
} 

my $hazardous_outlook_time = "";

my $txt_url = Config::get_value_for("hazardous_outlook");
my $text = LWP::Simple::get($txt_url);  
die "$current_date_time : Could not retrieve $txt_url" unless $text;
$text = lc($text);
if ( $text =~ m/^(.*)edt(.*)$/m ) {
    $hazardous_outlook_time = $1; 
}


my @alert_button_loop;

my $alert_buttons_exist = 0;

foreach my $key ( keys %alerts )
{
    my %button_hash = ();

    my $x_txt_url = $alerts{$key};
    my $x_text = LWP::Simple::get($x_txt_url);  
    die "$current_date_time : Could not retrieve $x_txt_url" unless $text;
    $x_text = lc($x_text);

    my $msg = "";
    if ( $x_text =~ m/<h3>$key<\/h3><pre>(.*)<\/pre><hr \/><br \/><h3>/is ) {
        $msg = $1;
    } elsif ( $x_text =~ m/<h3>$key<\/h3><pre>(.*)<\/pre><hr \/><br \/>/is ) {
        $msg = $1;
    } else {
        die "$current_date_time : could not parse file.";
    }    

    my $alert_time = "";
    if ( $msg =~ m/^(.*)edt(.*)$/m ) {
        $alert_time = $1; 
        $alert_time = Utils::reformat_nws_text_time($alert_time);
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

    $button_hash{url} = $filename;
    $button_hash{alert_time} = $alert_time;
    push(@alert_button_loop, \%button_hash);
    $alert_buttons_exist = 1;
}

my @meso_loop = get_mesoscale_info();


Web::set_template_name("wxindex");

Web::set_template_variable("refresh_button", 1);
Web::set_template_variable("refresh_button_url", Config::get_value_for("home_page")); 

Web::set_template_variable("hazardous_outlook_exists", $hazardous_outlook_exists);
Web::set_template_variable("hazardous_outlook_time", $hazardous_outlook_time);

Web::set_template_loop_data("buttonalerts" , \@alert_button_loop);

Web::set_template_variable("conditions_time",        $conditions{updatedate});
Web::set_template_variable("conditions_weather",     $conditions{weather});
Web::set_template_variable("conditions_temperature", $conditions{temperature});

Web::set_template_variable("forecast_time", $forecast_creation_date);

Web::set_template_variable("discussion_time", $discussion_time);

Web::set_template_variable("marine_time", $marine_time);

Web::set_template_loop_data("mesoscale" , \@meso_loop) if @meso_loop;

my $html_output = Web::display_page("Toledo Weather", "returnoutput");

open FILE, ">$html_output_filename" or die "$current_date_time : could not create file $html_output_filename";
print FILE $html_output;
close FILE;


sub get_mesoscale_info {

    my @array;
    
    # reference to an array of hasshes
    my $mdtree = read_and_parse_xml_file("spc_md_xml");
    my $mdarrref = $mdtree->{'rss'}->{'channel'}->{'item'};
    if ( ref $mdarrref eq ref [] ) {
        foreach my $mditem ( @$mdarrref ) {
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
                if ( $content =~ m/^(.*)edt(.*)$/m ) {
                    $mdtime = $1; 
                    $mdtime = Utils::reformat_nws_text_time($mdtime);
                } elsif ( $content =~ m/^(.*)cdt(.*)$/m ) {
                    $mdtime = $1; 
                    $mdtime = Utils::reformat_nws_text_time($mdtime, "cdt");
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

                create_mesoscale_file(\%mdhash); 

                push(@array, \%hash);

            } 
        }
    }

    return @array;
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
