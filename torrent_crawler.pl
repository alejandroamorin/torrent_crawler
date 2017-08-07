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

my $HYPHEN 	= '-';
my $PLUS	= '+';

# Objects
my $browser = LWP::UserAgent->new;
my $mechanize = WWW::Mechanize->new();

# 	url (0), search (1), separator (2), type of search (3), type of download (4), type of torrent (5)
my @WEBS = (
	['http://tumejortorrent.com', 	'/buscar', 								$HYPHEN, 	"1",	"1",	"1"],
	['http://www.newpct.com', 		'/buscar-descargas/', 					$HYPHEN, 	"1",	"2",	"2"],
	['http://www.mejortorrent.com', '/secciones.php?sec=buscador&valor=', 	$PLUS, 		"2",	"3",	"3"],
	['http://torrentlocura.com', 	'/buscar', 								$HYPHEN, 	"1",	"1",	"1"],
	['http://torrentrapid.com', 	'/buscar', 								$HYPHEN, 	"1",	"1",	"1"],
);

if ($ARGV[0]) {
	$search_word = $ARGV[0];
} else {
	print "\n\tNo keyword provided, enter one: ";
	my $keyword = <STDIN>;
	chop($keyword);
	$search_word = $keyword;
}

my $size = Get2DArraySize(@WEBS);

print "\n";
print Line();
my $se = AskPage();
print Line();
print "\n";

if ($se eq "C" || $se eq "c") {
	die "\nQuitting." 
} else {
	$se = $se - 1;
	$BASE_URL 	= $WEBS[$se][0];
	$SEARCH_URL = $BASE_URL.$WEBS[$se][1];
}

my @links = GetLinks();

#
# Intro menu
#
sub AskPage {
	print "\n\t\tIn which page do you want to search?: ";
	
	for (my $i=0; $i < $size; $i++) {
		my $x = $i+1;
		print "\n\t\t\t($x): ".$WEBS[$i][0];
	}

	print "\n";
	print "\n\t\t\t(C): Cancel\n\t\t";
	
	print "\n\t\t";
	my $pn = <STDIN>;
	chop($pn);
	
	unless ($pn =~ m/[cC1-5]+/) {
		$pn = AskPage();
	}
	
	return $pn;
}

#
# Get links for each torrent webpage search form
#
sub GetLinks {
	my $response;
	
	my $separator 		= $WEBS[$se][2];
	my $type_of_search 	= $WEBS[$se][3];
	
	$search_word = ReplaceSpaces($search_word, $separator);
	
	switch ($type_of_search) {
		case 1 { 
			$response = $browser->post($SEARCH_URL, ['q' => $search_word, 'submit' => 'submit']); 
		}
		case 2 {
			$response = $browser->post($SEARCH_URL.$search_word);
			$search_word = ReplaceSpaces($search_word, $HYPHEN);
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

	my $type_of_download = $WEBS[$se][4];

	switch( $type_of_download ) {
		case 1 {
			@clean_urls = GetDownloads1($web);	
		}
		case 2 {
			@clean_urls = GetDownloads2($web);
		}
		case 3 {
			@clean_urls = GetDownloads3($web, $round);
		}
	}
	
	@clean_urls = Distinct(@clean_urls);
	
	$downloads_size = @clean_urls;
	
	print "\n|";
	print Line();
	
	unless($round) {
		print "\n|\t$downloads_size ocurrences found with '$search_word':\n|";
	}
	
	for (my $i=0; $i<$downloads_size; $i++) {
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
# Get clean url downloads1
#
sub GetDownloads1 {
	my $web = shift;
	my @lines = split /\n/, $web;
	my @downloads;
	my @urls;
	my @clean_urls;
	
	foreach my $line (@lines) {
		$line = lc $line;
		if ($line =~ m/\<a href=\"$BASE_URL\/descargar/ && $line =~ lc $search_word) {
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
# Get clean url downloads2
#
sub GetDownloads2 {
	my $web = shift;
	my @lines = split /\n/, $web;
	my @downloads;
	my @urls;
	my @clean_urls;
	
	foreach my $line (@lines) {
		$line = lc $line;
		if ($line =~ m/\<a href=\"$BASE_URL\/descargar/ && $line =~ lc $search_word) {
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
# Get clean url downloads3
#
sub GetDownloads3 {
	my $web = shift;
	my $round = shift;
	my @lines = split /<a href='/, $web;
	my @downloads;
	my @urls;
	my @clean_urls;
		
	foreach my $line (@lines) {
		$line = lc $line;
		if ($line =~ lc $search_word) {
			print "\nLinea: ".$line;
			unless ($line =~ "musica" || $line =~ "DOCTYPE" || $line =~ "juego-descargar") {
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
	
	my $type_of_torrent = $WEBS[$se][5];

	switch( $type_of_torrent ) {
		case 1 {
			$count = GetTorrent1(@lines);
		}
		case 2 {
			$count = GetTorrent2(@lines);
		}
		case 3 {
			$count = GetTorrent3(@lines);
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
# Get torrent1
#
sub GetTorrent1 {
	my @lines = (@_);
	my $count = 0;
	
	foreach my $line (@lines) {
		if ($line =~ m/window.location.href/) {
			$line =~ s/^\s+window.location.href = \"//;
			$line =~ s/\"\;//;
			$count = DownloadFile($line);				
		}
		elsif ($line =~ m/\"txt_password\"/) {
			$line =~ s/^\s+.+value=\"//;
			$line =~ s/\".+//;
			print "\n\tPassword for torrent found: $line\n";
		}
	}
	
	return $count;
}

#
# Get torrent2
#
sub GetTorrent2 {
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
# Get torrent3
#
sub GetTorrent3 {
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
	$mechanize->save_content( $DEST_FOLDER."/".$filename.".torrent" );
	print "\n\tDownloaded $filename.torrent in $DEST_FOLDER/\n\n";
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
# Replace spaces for several words search
#
sub ReplaceSpaces {
	my $word = shift;
	my $replace_character = shift;
	$word =~ s/ /$replace_character/g;
	$word =~ tr/"'/ /;
	$word =~ tr/ //ds;
	return $word;
}

#
# Get 2D array column size
#
sub Get2DArraySize {
	my @array = (@_);
	my $size = 0;
	for (my $i=0; $i <= scalar (@{$array[0]}); $i++) {
		$size += 1 if $array[$i][0];
	}
	return $size;
}

#
# Line
#
sub Line {
	return "------------------------------------------------------------------------------------------------------------------------------------";
}
