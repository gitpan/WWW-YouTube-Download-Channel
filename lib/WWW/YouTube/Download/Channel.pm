package WWW::YouTube::Download::Channel;
use Moose;
use WWW::Mechanize;
use XML::XPath;
use XML::XPath::XMLParser;
use WWW::YouTube::Download;
use Text::Unaccent;

our $VERSION     = '0.01';

has agent => (
    is      => 'rw',
    isa     => 'WWW::Mechanize',
    default => sub {
        my $mech = WWW::Mechanize->new();
        $mech->agent_alias('Windows IE 6');
        return $mech;
    },
);

has xmlxpath => (
    is  => 'rw',
    isa => 'XML::XPath',
);

has video_list_ids => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {
        my @arr;
        return \@arr;
    },
);

has total_user_videos => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has total_download_videos => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has entry_url => (
    is  => 'rw',
    isa => 'Str',
);

has channel => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has url_next => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has page_video_found => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has start_index => (    #page index
    is      => 'rw',
    isa     => 'Int',
    default => 1,
);

has max_results => (    #limit results per page retrieved
    is      => 'ro',
    isa     => 'Int',
    default => 50, #youtube limit 
);

has target_directory => (
    is  => 'rw',
    isa => 'Str',
);

has filter_title_regex => (
    is  => 'rw',
    isa => 'Str',
);

has debug => (
    is  => 'rw',
    isa => 'Int',
    default => 0,
);

sub parse_page {
    my ( $self, $html_content ) = @_;
    my $xml = XML::XPath->new( xml => $html_content );
    $self->page_video_found(0);
    my $nodeset = $xml->findnodes('//entry');
    foreach my $node_html ( $nodeset->get_nodelist ) {
        if ( $node_html->string_value =~
            m{^http://gdata.youtube.com/feeds/api/videos} )
        {
            $self->page_video_found( $self->page_video_found + 1 );
            $self->total_user_videos( $self->total_user_videos + 1 );
            my $xml_details =
              XML::XPath->new(
                xml => XML::XPath::XMLParser::as_string($node_html) );
            my $video_id = my $video_url = $xml_details->findvalue('//id');
            $video_id =~ s{http://gdata.youtube.com/feeds/api/videos/}{}i;
            my $video_title = $xml_details->findvalue('//title');
            warn "Video_id: " . $video_id if ($self->debug == 1);
            warn "Title: " . $video_title if ($self->debug == 1);
            my $regex = $self->filter_title_regex
              if !!$self->filter_title_regex;

            if ( !$regex || $video_title =~ m/$regex/i ) {
                $self->total_download_videos(
                    $self->total_download_videos + 1 );
                push @{ $self->video_list_ids },
                  {
                    id       => $video_id,
                    title    => $video_title,
                    url      => $video_url,
                    filename => $self->title_to_filename($video_title),
                  };
            }
            undef $xml_details;
        }
    }
    undef($xml);
}

sub title_to_filename {
    my ( $self, $title ) = @_;
    $title =~ s/\W/-/ig;
    $title =~ s/--{1,}/-/ig;
    $title =~ s/^-|-$//ig;
    my $filename = unac_string( 'UTF8', $title );
    return $filename;
}

sub entry {
    my ( $self, $url ) = @_;
    $self->entry_url($url);
    $self->define_next_url();
    $self->list_videos();
}

sub leech_channel {
    my ( $self, $channel ) = @_;
    $self->channel($channel);
    $self->entry(
        'https://gdata.youtube.com/feeds/api/users/' . $channel . '/uploads' )
      if defined $channel;
}

sub define_next_url {
    my ($self) = @_;
    my $uri = URI->new( $self->entry_url );
    $uri->query_form(
        'start-index' => $self->start_index,
        'max-results' => $self->max_results,
    );
    $self->url_next( $uri->as_string );
}

sub list_videos {
    my ($self) = @_;
    $self->agent->get( $self->url_next );
    $self->parse_page( $self->agent->content );
    while ( $self->page_video_found > 0 )
    {
        $self->start_index( $self->start_index + $self->max_results );
        $self->define_next_url();
        $self->list_videos();
    }
}

sub download_all {
    my ($self) = @_;
    my $client = WWW::YouTube::Download->new;

    my $counter = 0;
    warn 'Total '
      . $self->total_user_videos
      . ' videos found for channel '
      . $self->channel;
    foreach my $item ( @{ $self->video_list_ids } ) {
        $counter++;
        my $filename =
          ( defined $self->target_directory )
          ? $self->target_directory . '/' . $item->{filename}
          : $item->{filename};

        warn $counter . '/'
          . $self->total_download_videos
          . ' - Downloading: '
          . $item->{title}
          . ' into '
          . $filename;

        $client->download( $item->{id}, { ( file_name => $filename ), } )
          if ( !-e $filename );
    }
}

sub apply_regex_filter {
    my ( $self, $regex ) = @_;
    $self->filter_title_regex($regex);
}

=head1 NAME

    WWW::YouTube::Download::Channel - Downloads all/every/some of the videos from any youtube user channel

=head1 SYNOPSIS

    use WWW::YouTube::Download::Channel;
    my $yt = WWW::YouTube::Download::Channel->new();

    $yt->target_directory('/youtuve/thiers48'); #OPTIONAL. default is current dir
    $yt->apply_regex_filter('24 horas|24H');    #OPTIONAL apply regex filters by title.. 
    $yt->leech_channel('thiers48');             #REQ
    $yt->download_all;                          #REQ find and download youtube videos

    warn "total user vids: " . $yt->total_user_videos;
    warn "total downloads: " . $yt->total_download_videos;

    #use Data::Dumper;
    #warn Dumper $yt->video_list_ids;

=head1 DESCRIPTION

    Use WWW::YouTube::Download::Channel to download a complete youtube channel / user videos.
    Just pass the channel id and download all the flv directly onto your hdd for later usage.
    Enjoy!

=head1 AUTHOR

    Hernan Lopes
    CPAN ID: HERNAN
    hernanlopes <.d0t.> gmail

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

1;

