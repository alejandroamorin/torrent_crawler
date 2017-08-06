#!/usr/bin/perl
use strict; 
use warnings; 
use LWP::UserAgent;
use WWW::Mechanize;
use Switch;

# Folder for torrent downloads
my $DEST_FOLDER = "descargas";

# ~~~~
my $BASE_URL;
my $SEARCH_URL;
my $search;
my $web_call;
my $selected_url;
my $downloads_size;
my $search_word;

# Objects
my $browser = LWP::UserAgent->new;
my $mechanize = WWW::Mechanize->new();

if ($ARGV[0]) {
	$search_word = $ARGV[0];
} else {
	print "\n\tNo keyword provided, enter one: ";
	my $keyword = <STDIN>;
	chop($keyword);
	$search_word = $keyword;
}

print "\n";
print Line();
my $se = AskPage();
print Line();
print "\n";

switch ($se) {
	case 1 { 
		$BASE_URL 	= "http://tumejortorrent.com";
		$SEARCH_URL = $BASE_URL . "/buscar";
		$search		= "tumejortorrent";
	}
	case 2 {
		$BASE_URL	= "http://www.newpct.com";
		$SEARCH_URL = $BASE_URL . "/buscar-descargas/";
		$search		= "newpct";
	}
	case 3 {
		$BASE_URL	= "http://www.mejortorrent.com";
		$SEARCH_URL = $BASE_URL . "/secciones.php?sec=buscador&valor=";
		$search		= "mejortorrent";
	}
	else {
		die "\nQuitting." 
	}
}

my @links = GetLinks();

#
# Intro menu
#
sub AskPage {
	print "\n\t\tIn which page do you want to search?: ";
	print "\n\t\t\t(1): http://tumejortorrent.com";
	print "\n\t\t\t(2): http://www.newpct.com";
	print "\n\t\t\t(3): http://www.mejortorrent.com";
	print "\n";
	print "\n\t\t\t(C): Cancel\n\t\t";
	my $pn = <STDIN>;
	chop($pn);
	
	unless ($pn =~ m/[cC1-3]+/) {
		$pn = AskPage();
	}
	
	return $pn;
}

#
# Get links for each torrent webpage search form
#
sub GetLinks {
	my $response;
		
	switch( $search ) {
		case "tumejortorrent" { 
			$response = $browser->post($SEARCH_URL, ['q' => $search_word, 'submit' => 'submit']);
		}
		case "newpct" {
			$response = $browser->post($SEARCH_URL, ['q' => $search_word, 'submit' => 'submit']);
		}
		case "mejortorrent" {
			$response = $browser->post($SEARCH_URL.$search_word);
		}
	}
	
	return GetDownloads( $response->content, undef );
}

#
# Get downloads for each page
#
sub GetDownloads {
	my $web = shift;
	my $round = shift;
	my @clean_urls;

	switch( $search ) {
		case "tumejortorrent" {
			@clean_urls = GetDownloads_Tumejortorrent($web);
		}
		case "newpct" {
			@clean_urls = GetDownloads_Newpct($web);
		}
		case "mejortorrent" {
			@clean_urls = GetDownloads_Mejortorrent($web, $round);
		}
	}
	
	@clean_urls = Distinct(@clean_urls);
	
	$downloads_size = @clean_urls;
	
	print "\n|";
	print Line();
	
	unless($round) {
		print "\n|\t$downloads_size ocurrences found with '$search_word':\n|";
	}
	
	for (my $i=0; $i< $downloads_size; $i++) {
		print "\n|\t(".($i+1)."): \t$clean_urls[$i]\n|";
	}
	
	print Line();
	print "\n";

	if ($downloads_size != 0) {
		$selected_url = $BASE_URL.$clean_urls[(GetDownloadNumber()-1)];
		my $response = $browser->post($selected_url);
		GetTorrent( $response->content );
	}
}

#
# Get clean url downloads from tumejortorrent.com
#
sub GetDownloads_Tumejortorrent {
	my $web = shift;
	my @lines = split /\n/, $web;
	my @downloads;
	my @urls;
	my @clean_urls;
	
	foreach my $line (@lines) {
		if ($line =~ m/\<a href=\"$BASE_URL\/descargar/ && $line =~ $search_word) {
			push @downloads, $line;
		}
	}
		
	foreach my $download (@downloads) {
		@urls = split /\<a href=\"(.*?)\"/, $download;
	}
		
	foreach (@urls) {
		if ($_ =~ m/^$BASE_URL/) {
			$_ =~ s/$BASE_URL//;
			push @clean_urls, $_;
		}
	}
	
	return @clean_urls;
}

#
# Get clean url downloads from newpct.com
#
sub GetDownloads_Newpct {
	my $web = shift;
	my @lines = split /\n/, $web;
	my @downloads;
	my @urls;
	my @clean_urls;
	
	foreach my $line (@lines) {
		if ($line =~ m/\<a href=\"$BASE_URL\/descargar/ && $line =~ $search_word) {
			push @downloads, $line;
		}
	}
		
	foreach my $download (@downloads) {
		$download =~ s/^\s+//;
		$download =~ s/\<a href=\"//;
		$download =~ s/\"(.+)//;
		push @urls, $download;
	}
		
	foreach (@urls) {
		if ($_ =~ m/^$BASE_URL/) {
			$_ =~ s/$BASE_URL//;
			push @clean_urls, $_;
		}
	}
	
	return @clean_urls;
}

#
# Get clean url downloads from mejortorrent.com
#
sub GetDownloads_Mejortorrent {
	my $web = shift;
	my $round = shift;
	my @lines = split /<a href='/, $web;
	my @downloads;
	my @urls;
	my @clean_urls;
		
	foreach my $line (@lines) {
		if ($line =~ $search_word) {
			unless ($line =~ "musica" || $line =~ "DOCTYPE") {
				push @downloads, $line;
			}
		}
	}

	foreach my $download (@downloads) {
		$download = substr($download, 0, index($download, "'")) if $round;
		$download =~ s/\'(.+)// unless $round;
		push @urls, $download;
	}
		
	foreach (@urls) {
		push @clean_urls, $_;
	}
	
	return @clean_urls;
}

#
# Return distinct elements
#
sub Distinct {
	my %seen;
	return grep { !$seen{$_}++ } @_;
}

#
# Takes selected download
#
sub GetDownloadNumber {
	print "\n\t\tWhich one do you want to download?: ";
	my $dn = <STDIN>;
	chop($dn);
	
	unless (($dn =~ m/[0-9]+/) && ($dn <= $downloads_size)) {
		$dn = GetDownloadNumber();
	}
	
	return $dn;
}

#
# Get torrent from each page
#
sub GetTorrent {
	my $web = shift;
	my @lines = split /\n/, $web;
	my $count;
	
	unless( -d $DEST_FOLDER ){
		mkdir $DEST_FOLDER;
	}
	
	switch ($search) {
		case "tumejortorrent" { 
			$count = GetTorrent_Tumejortorrent(@lines); 
		}
		case "newpct" { 
			$count = GetTorrent_Newpct(@lines); 
		}
		case "mejortorrent" { 
			$count = GetTorrent_Mejortorrent(@lines);
		}
	}
	
	if ($web_call) { $count = 1; } 
	unless ($count) {
		print "\n\n\tNo torrents found, it seems that there are several links:";
		my $response = $browser->post( $selected_url );
		GetDownloads( $response->content, 1 );
	}
}

#
# Get torrent from tumejortorrent.com
#
sub GetTorrent_Tumejortorrent {
	my @lines = (@_);
	my $count = 0;
	
	foreach my $line (@lines) {
		if ($line =~ m/window.location.href/) {
			$line =~ s/^\s+window.location.href = \"//;
			$line =~ s/\"\;//;
			$count = DownloadFile($line);				
		}
	}
	
	return $count;
}

#
# Get torrent from newpct.com
#
sub GetTorrent_Newpct {
	my @lines = (@_);
	my $count = 0;
	
	foreach my $line (@lines) {
		if ($line =~ m/.torrent\'/) {
			$line =~ s/.+\<a href=\'//;
			$line =~ s/\'.+//;
			$count = DownloadFile($line);		
		}
	}
	
	return $count;
}

#
# Get torrent from mejortorrent.com
#
sub GetTorrent_Mejortorrent {
	my @lines = (@_);
	my $count = 0;
	
	foreach my $line (@lines) {
		$line =~ s/.+\<a href=\'//;
		if ($line =~ m/.torrent\'/) {
			$line =~ s/\'.+//;
			$count = DownloadFile($BASE_URL."/".$line, $BASE_URL."/".$line);
		}
		
		unless( $web_call ) {
			if ($line =~ m/contar&/) {
				$line =~ s/\'.+//;
				my $selected_url = $BASE_URL."/".$line;
				my $response = $browser->post($selected_url);
				$web_call = 1;
				GetTorrent( $response->content );
			}
		}
	}
	
	return $count;
}
  
#
# Download file from url
#
sub DownloadFile {
	my $line = shift;
	$mechanize->get( $line );		
	my $filename = Sanitize( $selected_url );
	$mechanize->save_content( $DEST_FOLDER."\\".$filename.".torrent" );
	print "\n\tDownloaded $filename.torrent in $DEST_FOLDER/\n";
	return 1;
}

#
# Sanitizes parameters
#
sub Sanitize {
	my $name = shift;
	$name =~ tr|:/|_|;
	return $name;
}

#
# Line
#
sub Line {
	return "------------------------------------------------------------------------------------------------------------------------------------";
}