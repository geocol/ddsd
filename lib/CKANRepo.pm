package CKANRepo;
use strict;
use warnings;
use Time::HiRes qw(time);
use JSON::PS;
use Promise;
use Promised::Flow;
use Web::URL;
use Web::URL::Encoding;
use Web::DateTime::Parser;
use Promised::File;

use Repo;
push our @ISA, qw(Repo);

use CKANPackage;

sub new_from_set_and_url ($$$) {
  my ($class, $set, $url) = @_;

  my $self = bless {
    set => $set,
  }, $class;

  my $p;
  my $q;
  my $r;
  my $s;
  my $u = $url->stringify;
  # https://data.e-gov.go.jp/data/dataset/env_20140904_0813#contents
  # https://search.ckan.jp/datasets/136.187.101.184:5000__dataset:oai-irdb-nii-ac-jp-01081-0004523245
  if ($u =~ m{^(https?)://([^/]+)((?:/[0-9A-Za-z_.-]+)*|)/dataset/([^/?#]+)}) {
    $self->{scheme} = $1;
    $self->{host} = $2;
    $self->{prefix} = $3;
    $self->{id} = percent_decode_c $4;

    $p = q<%s://%s%s/api/action/package_show?id=%s>;
    $q = q<%s://%s%s/dataset/%s>;
    $r = q<%s://%s%s/dataset/activity/%s>;
    $s = q<%s://%s%s/>;
  } elsif ($u =~ m{^(https?)://(search\.ckan\.jp)()/datasets/([^/?#]+)}) {
    $self->{scheme} = $1;
    $self->{host} = $2;
    $self->{prefix} = $3;
    $self->{id} = percent_decode_c $4;

    $p = q<%s://%s%s/backend/api/package_show?id=%s>;
    $q = q<%s://%s%s/datasets/%s>;
    $s = q<%s://%s%s/>;
  } else {
    return $self->set->app->logger->throw ({
      type => 'bad URL', format => 'CKAN dataset page URL',
      url => $u,
    });
  }
  $self->{api_url} = sprintf $p,
      $self->{scheme}, $self->{host}, $self->{prefix},
      percent_encode_c $self->{id};
  $self->{page_url} = sprintf $q,
      $self->{scheme}, $self->{host}, $self->{prefix},
      percent_encode_c $self->{id};
  $self->{activity_url} = sprintf $r,
      $self->{scheme}, $self->{host}, $self->{prefix},
      percent_encode_c $self->{id}
      if defined $r;
  $self->{root_url} = sprintf $s,
      $self->{scheme}, $self->{host}, $self->{prefix};
  $self->{url} = Web::URL->parse_string ($self->{page_url});
  $self->_set_key ($self->{url}->stringify);
  
  return $self;
} # new_from_set_and_url

sub type () { "ckan" }

sub fetch ($;%) {
  my ($self, %args) = @_;
  my $logger = $args{logger} // $self->set->app->logger;
  my $file_defs = $args{file_defs} || {};
  my $ret = {};
  my $package_updated = 0;
  my $package_item_key;
  my $url = Web::URL->parse_string ($self->{api_url});
  my $has_legal = defined $self->{mirror_url};
  return Promise->resolve->then (sub {
    return undef if $args{skip_fetch_legal} or $has_legal;
    return $self->_fetch_legal (
      $url,
      cacert => $args{cacert}, insecure => $args{insecure},
      has_error => $args{has_error},
      logger => $logger,
    );
  })->then (sub {
    my $x = $_[0];
    $has_legal = 1 if defined $x and defined $x->{legal_key};
    if ($args{is_special_repo}) {
      $x //= {};
      $x->{_} //= 1;
      $x->{timestamp} //= time;
      $ret->{timestamp} = $x->{timestamp};
    }
    return $self->_fetch_file (
      $url, $file_defs->{'meta:ckan.json'},
      %args,
      mime => 'json',
      dest_type => 'meta',
      set_repo_type => 1,
      skip_if_found => $args{no_update},
      skip_if_new => $args{is_special_repo},
      force_fetch => (defined $x),
      fetch_log => $x, # or undef
      logger => $logger,
    );
  })->then (sub {
    my $r = $_[0];
    $package_item_key = $r->{key}; # or undef
    $ret->{insecure} = 1 if $r->{insecure};
    if ($r->{error}) {
      if ($args{requires_package}) {
        return $logger->throw ({
          type => 'no CKAN package available',
          url => $r->{url}->stringify,
        });
      }
      $args{has_error}->();
      $logger->count (['fetch_failure']);
    } elsif ($r->{not_modified}) {
      if ($r->{is_new}) {
        $ret->{timestamp} = $r->{is_new};
        $ret->{_skip} = 1;
        return;
      } else {
        #
      }
    } else {
      $package_updated = 1;
    }
    
    my $as;
    return $self->get_item_list (
      with_source_meta => 1, file_defs => $file_defs,
      has_error => $args{has_error},
      skip_other_files => $args{skip_other_files},
      requires_package => 1,
      requires_legal => 1,
      with_skipped => defined $args{file_key},
      skip_if_found => $args{no_update},
      with_item_key => 1,
      data_area_key => $args{data_area_key},
      report_unexpandable_set_type => 1,
    )->then (sub {
      my $all_files = shift;
      if (@$all_files) {
        shift @$all_files;
        $ret->{has_package} = 1;
      } else {
        return;
      }
      my $files = [];
      if (defined $args{only}) {
        if ($args{only} eq 'package' or $args{only} eq 'meta:ckan.json') {
          return;
        } else {
          for my $file (@$all_files) {
            if ($file->{key} eq $args{only}) {
              push @$files, $file;
              last;
            }
          }
        }
      } elsif ($args{skip_unless_new_package} and
               not $package_updated) {
        return;
      } elsif ($args{min}) {
        my $count = 10;
        for my $file (@$all_files) {
          if ($file->{type} eq 'meta') {
            push @$files, $file;
            next;
          }
          if ($file->{type} eq 'package' or
              $file->{type} eq 'dataset') {
            $logger->count (['add_skipped']);
            next;
          }
          if (--$count < 0) {
            $logger->count (['add_skipped']);
            next;
          }
          my $item = $file->{ckan_resource} || {};
          if ($item->{size} and $item->{size} > 100_000_000) {
            $logger->info ({
              type => 'skipped large file',
              url => $item->{url}, # or undef
              key => $file->{key},
              value => $item->{size},
            });
            $logger->count (['add_skipped']);
            next;
          } else {
            use utf8;
            if (defined $item->{description} and
                $item->{description} =~ m{: ファイルサイズは ([0-9]+\.[0-9]+) MB です。$}) {
              my $size = $1 * 1024 * 1024;
              if ($size > 100_000_000) {
                $logger->info ({
                  type => 'skipped large file',
                  url => $item->{url}, # or undef
                  key => $file->{key},
                  value => $size,
                });
                $logger->count (['add_skipped']);
                next;
              }
            }
          }
          if (not defined $item->{url} or $item->{url} =~ m<\{>) {
            $logger->count (['add_skipped']);
            next;
          }
          my $u = Web::URL->parse_string ($item->{url});
          if (not defined $u and not $u->is_http_s) {
            $logger->count (['add_skipped']);
            next;
          }
          push @$files, $file;
        }
      } else {
        push @$files, @$all_files;
      }

      $as = $logger->start (0+@$files, {
        type => 'pull package files',
        all_count => 0+@$all_files,
        selected_count => 0+@$files,
      });
      return promised_for {
        my $file = shift;
        $as->{next}->(undef, undef, {key => $file->{key}});
        return if $file->{key} eq 'meta:ckan.json';
        return if $file->{type} eq 'dataset';

        my $res = $file->{ckan_resource} || {};
        my $u = $file->{source}->{url};

        if (not defined $u) {
          $args{has_error}->();
          $as->message ({
            type => 'broken file', format => 'CKAN resource',
            key => 'url',
            ckan_resource => $res,
            file => $file,
          });
          return;
        }
        my $url = Web::URL->parse_string ($u);
        if (not defined $url or not $url->is_http_s) {
          $args{has_error}->();
          $as->message ({
            type => 'bad URL',
            format => 'CKAN resource',
            value => $u,
            ckan_resource => $res,
            key => 'url',
            file => $file,
          });
          return;
        } elsif ($u =~ m<\{>) {
          $as->info ({
            type => 'URL template skipped',
            value => $u,
          });
          return;
        }

        my $he = $file->{key} =~ /^meta:/ ? sub { } : $args{has_error};
        return $self->_fetch_file (
          $url, $file_defs->{$file->{key}},
          %args,
          mime => $file->{source}->{mime},
          dest_type => ($file->{key} =~ /^meta:/ ? 'meta' : undef),
          has_error => $he,
          index_seen => 1, rev => $file->{rev}, item_key => $file->{item_key},
          logger => $as,
        )->then (sub {
          my $r = $_[0];
          $ret->{insecure} = 1 if $r->{insecure};
          if ($r->{error}) {
            $he->();
            $as->count (['fetch_failure']);
          }
        });
      } $files;
    })->then ($as->{ok}, $as->{ng});
  })->then (sub {
    return if $ret->{_skip};
    return if not defined $package_item_key;
    return if $has_legal;
    return $self->_fetch_post_legal (
      %args,
      dest_item_key => $package_item_key,
      fallback_source => {
        type => 'ckansite',
        url => $self->{root_url},
        files => {
          "file:index.html" => {},
          "file:about.html" => {},
        },
        skip_other_files => 1,
      },
      logger => $logger,
    );
  })->then (sub {
    return $ret;
  });
} # fetch

## <https://wiki.suikawiki.org/n/CKAN%E8%B3%87%E6%BA%90#header-section-CKAN-%E8%B3%87%E6%BA%90%E2%80%A8MIME-%E5%9E%8B>
my $ToComputedMIME = {};
{
  for (
    ['application/zip', 'BVF' => 'application/bvf+zip'],
    ['application/vnd.oma.drm.message', '' => 'application/dm'],
    ['application/vnd.ms-excel', 'XLSX' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['application/zip', 'XLSX' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['application/json', 'GeoJSON' => 'application/geo+json'],
    ['text/xml', 'RDF' => 'application/rdf+xml'],
  ) {
    $ToComputedMIME->{$_->[0], lc $_->[1]} = $_->[2];
    $ToComputedMIME->{lc $_->[1]} = $_->[2] if length $_->[1];
  }
  for (
    ['application/postscript', 'ai', 'ai' => 'application/illustrator'],
    ['application/postscript', '', 'ai' => 'application/illustrator'],
  ) {
    $ToComputedMIME->{$_->[0], lc $_->[1], $_->[2]} = $_->[3];
    $ToComputedMIME->{lc $_->[1]} = $_->[3] if length $_->[1];
  }
  for (
    ['CSV' => 'text/csv'],
    ['dm' => 'application/dm'],
    ['image/vnd.dxf' => 'image/vnd.dxf'],
    ['XLSX' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
    ['PDF' => 'application/pdf'],
    ['TIFF' => 'image/tiff'],
    ['ttl' => 'text/turtle'],
    ['ZIP' => 'application/zip'],
  ) {
    $ToComputedMIME->{lc $_->[0]} = $_->[1];
  }
}

my $MIMEToExt = {};
my $ExtToMIME = {};
for (
  ['image/vnd.dxf' => ['dxf']],
  ['image/gif' => ['gif']],
  ['image/jpeg' => ['jpeg', 'jpg']],
  ['image/png' => ['png']],
  ['image/tiff' => ['tiff', 'tif']],
  ['audio/mpeg' => ['mp3']],
  ['video/mp4' => ['mp4']],
  ['text/csv' => ['csv']],
  ['text/html' => ['html', 'htm']],
  ['text/markdown' => ['md']],
  ['text/plain' => ['txt']],
  ['text/turtle' => ['ttl']],
  ['text/xml' => ['xml']],
  ['application/ai' => ['ai']],
  ['application/vnd.android.package-archive' => ['apk']],
  ['application/vnd.dbf' => ['dbf']],
  ['application/dm' => ['dm']],
  ['application/msword' => ['doc']],
  ['application/vnd.openxmlformats-officedocument.wordprocessingml.document' => ['docx']],
  ['application/geo+json' => ['geojson', 'json'], ['geojson']],
  ['application/json' => ['json']],
  ['application/vnd.google-earth.kml+xml' => ['kml']],
  ['application/pdf' => ['pdf']],
  ['application/vnd.ms-powerpoint' => ['ppt']],
  ['application/vnd.openxmlformats-officedocument.presentationml.presentation' => ['pptx']],
  ['application/rdf+xml' => ['rdf', 'xml'], ['rdf']],
  ['application/vnd.ms-excel' => ['xls']],
  ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => ['xlsx']],
  ['application/vnd.ms-excel.sheet.macroEnabled.12' => ['xlsm']],
  ['application/zip' => ['zip']],
) {
  my ($mime, $exts) = @{$_};
  my $exts2 = $_->[2] // $exts;
  $MIMEToExt->{$mime} = $exts;
  for my $ext (@$exts2) {
    $ExtToMIME->{$ext} = $mime;
  }
}

sub get_item_list ($;%) {
  my ($self, %args) = @_;
  my $logger = $self->set->app->logger;
  my $storage_path = $self->storage->{path};
  my $file_defs = $args{file_defs} || {};
  return $self->read_index->then (sub {
    my $in = $_[0];
    my $files = [];

    my $with_package = not $args{no_package};
    if (defined $file_defs->{'meta:ckan.json'} and
        $file_defs->{'meta:ckan.json'}->{skip}) {
      $with_package = 0;
    }
    $with_package = 1 if $args{requires_package} or
                         $args{with_snapshot_hash} or
                         $args{requires_legal};

    if ($with_package) {
      my $file0 = {
        type => 'package',
        key => 'package',
        package_item => {
          title => '',
          lang => '',
          dir => 'auto',
          writing_mode => 'horizontal-tb',
          page_url => $self->{page_url},
          ckan_api_url => $self->{api_url},
        },
      };
      my $file = {
        type => 'meta',
        key => 'meta:ckan.json',
        package_item => {
          mime => 'application/json',
          title => '',
        },
        file => {
          directory => 'package',
          name => 'package.ckan.json',
        },
      };
      if (defined $file_defs->{'meta:ckan.json'} and
          defined $file_defs->{'meta:ckan.json'}->{name}) {
        $file->{file}->{directory} = 'files';
        $file->{file}->{name} = $file_defs->{'meta:ckan.json'}->{name};
      }
      push @$files, $file0, $file;
    }
    
    my $item;
    my $item_key;
    if ($args{skip_other_files} and
        not defined $file_defs->{'meta:ckan.json'} and
        not $with_package) {
      $logger->info ({
        type => 'item ignored by skip_other_files',
        key => 'meta:ckan.json',
        path => $in->path->absolute,
      });
    } else {
      ($item_key, $item) = $in->get_item
          ($self->{api_url}, file_def => $file_defs->{'meta:ckan.json'});
    }
    if (not defined $item) {
      $logger->message ({
        type => 'no local copy available',
        url => $self->{api_url},
      });
      $args{has_error}->();
    }

    my $package_insecure = 0;
    if ($with_package and defined $item) {
      my $file = $files->[1];
      if (defined $item->{rev}) {
        $file->{rev} = $item->{rev};
        $file->{item_key} = $item_key if $args{with_item_key};
        if (defined $file->{rev}->{http_content_type}) {
          $file->{package_item}->{mime} = $file->{rev}->{http_content_type};
        }
        if (defined $file->{rev}->{http_last_modified}) {
          $file->{package_item}->{file_time} = $file->{rev}->{http_last_modified};
        }
        $package_insecure = 1 if $file->{rev}->{insecure};
      }
      if ($args{with_path}) {
        $file->{path} = $storage_path->child ($item->{files}->{data})
            if defined $item->{files}->{data};
        $file->{meta_path} = $storage_path->child ($item->{files}->{meta})
            if defined $item->{files}->{meta};
        $file->{log_path} = $storage_path->child ($item->{files}->{log})
            if defined $item->{files}->{log};
      }
    } # $with_package

    my $pack_items = {};
    my $pack_files = {};
    for (
      ['activity.html', 'activity_url'],
      ($self->{host} eq 'data.bodik.jp' ? ['index.html', 'page_url'] : ()),
    ) {
      my ($file_name, $url_key) = @$_;
      my $file_key = 'meta:' . $file_name;
      if (defined $self->{$url_key}) {
        if ($args{skip_other_files} and
            not defined $file_defs->{$file_key} and
            not $args{requires_legal}) {
          $logger->info ({
            type => 'item ignored by skip_other_files',
            value => $file_key,
            path => $in->path->absolute,
          });
        } else {
          (undef, $pack_items->{$file_key}) = $in->get_item
              ($self->{$url_key}, file_def => $file_defs->{$file_key});
        }

        if ($with_package) {
          my $file = {
            type => 'meta',
            key => $file_key,
            package_item => {
              mime => 'text/html;charset=utf-8',
              title => '',
            },
            file => {
              directory => 'package',
              name => $file_name,
            },
          };
          if (defined $file_defs->{$file_key} and
              defined $file_defs->{$file_key}->{name}) {
            $file->{file}->{directory} = 'files';
            $file->{file}->{name} = $file_defs->{$file_key}->{name};
          }
          $file->{source}->{url} = $self->{$url_key};
          push @$files, $pack_files->{$file_key} = $file;

          if (defined $pack_items->{$file_key}) {
            my $skipped = $file_defs->{$file_key}->{skip};
            $file->{rev} = $pack_items->{$file_key}->{rev}
                unless $skipped; # XXX tests for skipped
            if (defined $file->{rev}) {
              if (defined $file->{rev}->{http_content_type}) {
                $file->{package_item}->{mime} = $file->{rev}->{http_content_type};
              }
              $file->{package_item}->{file_time} = $file->{rev}->{http_last_modified} // $file->{rev}->{http_date} // $file->{rev}->{timestamp};
              $package_insecure = 1 if $file->{rev}->{insecure};
            }
            if ($args{with_path}) {
              $file->{path} = $storage_path->child
                  ($pack_items->{$file_key}->{files}->{data})
                  if defined $item->{files}->{data};
              $file->{meta_path} = $storage_path->child ($item->{files}->{meta})
                  if defined $item->{files}->{meta};
              $file->{log_path} = $storage_path->child ($item->{files}->{log})
                  if defined $item->{files}->{log};
            }
          }
        } # $with_package
      }
    } # file
    $pack_items->{legal} = $self->{host} eq 'data.bodik.jp' ? $pack_items->{"meta:index.html"} : $pack_items->{"meta:activity.html"};
    $pack_files->{legal} = $self->{host} eq 'data.bodik.jp' ? $pack_files->{"meta:index.html"} : $pack_files->{"meta:activity.html"};

    return $files if not defined $item;
    return Promise->all ([
      CKANPackage->open_api_response_by_app_and_path (
        $self->set->app, $self->storage->{path}->child ($item->{files}->{data}),
      ),
      ($args{with_props} ? $self->set->app->get_legal_json ('ckan.json') : undef),
      (($args{with_props} and defined $item->{files}->{log}) ? Promised::File->new_from_path ($self->storage->{path}->child ($item->{files}->{log}))->read_byte_string : undef),
      (($with_package and defined $pack_items->{legal} and defined $pack_items->{legal}->{files}->{data}) ? Promised::File->new_from_path ($self->storage->{path}->child ($pack_items->{legal}->{files}->{data}))->read_byte_string : undef),
    ])->then (sub {
      my ($pack, $legal, $log_bytes, $acts_bytes) = @{$_[0]};
      unless (defined $pack) {
        $args{has_error}->();
        return $files;
      }

      if (defined $acts_bytes) {
        my $base_url = Web::URL->parse_string
            ($pack_items->{legal}->{rev}->{url});
        my $url = $self->_sniff_terms_url_in_html ($acts_bytes, $base_url);
        $pack_files->{legal}->{parsed}->{site_terms_url} = $url
            if defined $url;
      }

      if ($with_package) {
        my $pack = $pack->get_package;
        $files->[1]->{ckan_package} = $pack if $args{with_source_meta};
        my $pi0 = $files->[0]->{package_item};
        my $pi = $files->[1]->{package_item};

        if ($args{with_props}) {
        if (not defined $pi->{file_time} and
            defined $pack->{metadata_modified}) {
          my $dtp = Web::DateTime::Parser->new;
          $dtp->onerror (sub { });
          my $dt = $dtp->parse_local_date_and_time_string
              ($pack->{metadata_modified});
          if (defined $dt) {
            $pi->{file_time} = $dt->to_unix_number;
          }
        }
        if (not defined $pi->{file_time} and
            defined $pack->{metadata_created}) {
          my $dtp = Web::DateTime::Parser->new;
          $dtp->onerror (sub { });
          my $dt = $dtp->parse_local_date_and_time_string ($pack->{metadata_created});
          if (defined $dt) {
            $pi->{file_time} = $dt->to_unix_number;
          }
        }
        if (not defined $pi->{file_time} and defined $files->[1]->{rev}) {
          $pi->{file_time} = $files->[1]->{rev}->{http_date} //
                             $files->[1]->{rev}->{timestamp};
        }

        $pi->{title} = $pack->{title} // '';
        $pi->{title} = $pack->{name} // '' unless length $pi->{title};
        $pi0->{title} = $pi->{title};
        $pi0->{legal} = [];

        if (defined $acts_bytes) {
          if ($acts_bytes =~ m{<html lang="([^"&]+)">}) {
            $pi0->{lang} = $1;
            $pi0->{lang} =~ tr/A-Z_/a-z-/;
          }
          
          if ($acts_bytes =~ m{<link rel="stylesheet"[^<>]*href="[^"]+/main(-rtl|)\.min\.css"\s*/>}) {
            ## CKAN (original)
            $pi0->{dir} = $1 ? 'rtl' : 'ltr';
          } elsif ($acts_bytes =~ m{<link href="[^"]*/gkan/[^"]*" rel="stylesheet"\s*/>}) {
            ## GKAN
            $pi0->{dir} = 'ltr';
          }

          $pi0->{writing_mode} = 'horizontal-tb';
        } # $acts_bytes

          my $extras_copyright = undef;
          if (defined $pack->{extras} and ref $pack->{extras} eq 'ARRAY') {
            for my $item (@{$pack->{extras}}) {
              if (defined $item and ref $item eq 'HASH' and
                  defined $item->{key} and defined $item->{value}) {
                use utf8;
                if ($item->{key} eq 'language' or
                    $item->{key} eq '言語') {
                  my $value = {
                    ja => 'ja', 'Japanese' => 'ja', '日本語' => 'ja',
                  }->{$item->{value}};
                  if (defined $value) {
                  $pi0->{lang} = $value;
                  } else {
                    $logger->info ({
                      type => 'unknown language value',
                      key => $item->{key},
                      value => $item->{value},
                      path => $in->path->absolute,
                    });
                  }
                } elsif ($item->{key} eq 'copyright') {
                  $extras_copyright = $item->{value} if length $item->{value};
                } # $item->{key}
              }
            } # $item
          } # extras

          my $tags = {};
          if (defined $pack->{tags} and ref $pack->{tags} eq 'ARRAY') {
            $tags = {map {
              (defined $_ and ref $_ eq 'HASH') ? ($_->{name} => 1, $_->{display_name} => 1) : ();
            } @{$pack->{tags}}};
          } # tags
          
          $legal = [] unless defined $legal and ref $legal eq 'ARRAY';
          for my $l (@$legal) {
            next unless defined $l and ref $l eq 'HASH';
            my $has_some = 0;
            
            if (not defined $l->{id} and not defined $pack->{license_id}) {
              #
            } elsif (defined $l->{id} and defined $pack->{license_id} and
                     $l->{id} eq $pack->{license_id}) {
              $has_some = 1;
            } else {
              next;
            }

            if (not defined $l->{title} and
                not defined $pack->{license_title}) {
              #
            } elsif (defined $l->{title} and defined $pack->{license_title} and
                     $l->{title} eq $pack->{license_title}) {
              $has_some = 1;
            } else {
              next;
            }

            if (not defined $l->{url} and not defined $pack->{license_url}) {
              #
            } elsif (defined $l->{url} and defined $pack->{license_url} and
                     $l->{url} eq $pack->{license_url}) {
              $has_some = 1;
            } else {
              next;
            }

            if (not defined $l->{agreement} and
                not defined $pack->{license_agreement}) {
              #
            } elsif (defined $l->{agreement} and
                     defined $pack->{license_agreement} and
                     $l->{agreement} eq $pack->{license_agreement}) {
              $has_some = 1;
            } else {
              next;
            }

            if (not defined $l->{extras_copyright} and
                not defined $extras_copyright) {
              #
            } elsif (defined $l->{extras_copyright} and
                     defined $extras_copyright and
                     $l->{extras_copyright} eq $extras_copyright) {
              $has_some = 1;
            } else {
              next;
            }

            if (defined $l->{tag}) {
              if ($tags->{$l->{tag}}) {
                $has_some = 1;
              } else {
                next;
              }
            }

            next if defined $l->{extracted_url};
            next if defined $l->{licenses};
            next unless $has_some;

            if (defined $l->{is}) {
              if ($l->{db}) {
                push @{$pi0->{legal}}, {type => 'db_license', key => $l->{is},
                                       source_type => 'package',
                                       source_url => $self->{api_url}};
                $pi0->{legal}->[-1]->{insecure} = 1 if $package_insecure;
              } else {
                push @{$pi0->{legal}}, {type => 'license', key => $l->{is},
                                       source_type => 'package',
                                       source_url => $self->{api_url}};
                $pi0->{legal}->[-1]->{insecure} = 1 if $package_insecure;
              }
              last;
            }
          } # $l
          if (not @{$pi0->{legal}}) {
            my $v = {type => 'license',
                     key => '-ddsd-ckan-package',
                     source_type => 'package',
                     source_url => $self->{api_url}};
            for (qw(license_id license_url license_title
                    license_agreement licenses)) {
              $v->{$_} = $pack->{$_} if defined $pack->{$_};
            }
            $v->{extras_copyright} = $extras_copyright
                if defined $extras_copyright;
            push @{$pi0->{legal}}, $v if 4 < keys %$v;
            $v->{insecure} = 1 if $package_insecure;
          }

        my $has_sokuryouhou = 0;
        if (defined $pack->{notes}) {
          use utf8;
          if ($pack->{notes} =~ m{\[[^\[\]]+利用規約\]\((https://[^()]+)\)}) {
            ## <https://catalog.registries.digital.go.jp/rc/dataset/ba-o1-073229_g2-000011>
            my $u = $1;
            push @{$pi0->{legal}}, {type => 'license',
                                    key => '-ddsd-ckan-package',
                                    source_type => 'package',
                                    source_url => $self->{api_url},
                                    extracted_url => $u,
                                    notes => $pack->{notes}};

            ## <https://www.digital.go.jp/policies/base_registry_address_tos>
            if ($u =~ /digital.go.jp/ and $pack->{notes} =~ /地番マスター/) {
              push @{$pi0->{legal}}, {type => 'license',
                                      key => '-ddsd-ckan-package',
                                      source_type => 'package',
                                      source_url => $self->{api_url},
                                      extracted_url => "https://www.geospatial.jp/ckan/dataset/houmusyouchizu-riyoukiyaku/resource/47871bf1-4c85-48f7-a8fe-b27c6643c1c5",
                                      notes => $pack->{notes}};
            }
          } elsif ($pack->{notes} =~ /利用規約/) {
            ## <https://data.bodik.jp/dataset/260002_douga-jitensyatou>
            push @{$pi0->{legal}}, {type => 'license',
                                   key => '-ddsd-ckan-package',
                                   source_type => 'package',
                                   source_url => $self->{api_url},
                                   notes => $pack->{notes},
                                   is_free => 'unknown'};
          }
          if ($pack->{notes} =~ /測量成果|測量法/) {
            push @{$pi0->{legal}}, {type => 'license',
                                   key => '-ddsd-jp-sokuryouhou',
                                   source_type => 'package',
                                   source_url => $self->{api_url}};
            $has_sokuryouhou = 1;
          }
          if ($pack->{notes} =~ /ライセンス/) {
            ## <https://opendata-api-kakogawa.jp/ckan/dataset/kakogawa_app>
            if ($pack->{notes} =~ m{(?:^|[\x0D\x0A])(?:ファイル|)ライセンス[：:]CC\s+BY-NC-ND\s+4\.0(?:[\x0D\x0A]|$)}) {
              push @{$pi0->{legal}}, {type => 'license',
                                      key => 'CC-BY-NC-ND-4.0',
                                      source_type => 'package',
                                      source_url => $self->{api_url}};
            } else {
              push @{$pi0->{legal}}, {type => 'license',
                                      key => '-ddsd-ckan-package',
                                      source_type => 'package',
                                      source_url => $self->{api_url},
                                      notes => $pack->{notes},
                                      is_free => 'unknown'};
            }
          }
        }
        if (defined $pack->{title}) {
          use utf8;
          if (not $has_sokuryouhou and $pack->{title} =~ /測量成果/) {
            push @{$pi0->{legal}}, {type => 'license',
                                   key => '-ddsd-jp-sokuryouhou',
                                   source_type => 'package',
                                   source_url => $self->{api_url}};
          }
        }

        for my $pl (@{$pi0->{legal}}) {
          next unless $pl->{extracted_url};
          
          for my $l (@$legal) {
            next unless defined $l and ref $l eq 'HASH';
            next if defined $l->{licenses};
            next unless defined $l->{is};
            
            if (defined $l->{extracted_url} and
                $l->{extracted_url} eq $pl->{extracted_url}) {

              if ($l->{db}) {
                $pl->{type} = 'db_license';
              } else {
                $pl->{type} = 'license';
              }
              $pl->{key} = $l->{is};
              $pl->{insecure} = 1 if $package_insecure;
              last;
            }
          }
        } # $pl

        if (defined $log_bytes) {
          $self->_parse_log_legal ($log_bytes => $pi0->{legal});
        } # $log_bytes
      } # with_props
    } # $with_package

      my $reses = $pack->get_resources;
      my $i = -1;
      my $found = {};
      for my $res (@$reses) {
        $i++;
        my $file = {};
        $file->{ckan_resource} = $res if $args{with_source_meta};
        my $url;
        if (defined $res->{url} and length $res->{url}) {
          my $u = $res->{url};
          $u =~ s{^(https?://[^/]+/)admin/(gkan/)}{$1$2};
          $url = Web::URL->parse_string ($u);
          $file->{source}->{url} = $url->stringify if defined $url;
        }
        
        if (defined $res->{id} and length $res->{id} and
            not $found->{$res->{id}}++) {
          $file->{key} = 'file:id:' . $res->{id};
        } else {
          $file->{key} = 'file:index:' . $i;
          $logger->info ({
            type => 'bad CKAN resource ID',
            value => $res->{id},
            path => $in->path->absolute,
          });
        }

        if (defined $res->{format} and $res->{format} eq 'fiware-ngsi') {
          $file->{type} = 'dataset';
          $file->{set_type} = $res->{format};
        } else {
          $file->{type} = 'file';
        }
        my $skipped;
        if (defined $file_defs->{$file->{key}} and
            $file_defs->{$file->{key}}->{skip}) {
          $skipped = 1;
          if ($args{with_skipped}) {
            #
          } else {
            $logger->info ({
              type => 'item ignored by skip',
              value => $file->{key},
              path => $in->path->absolute,
            });
            next;
          }
        }
        if ($args{skip_other_files} and
            not defined $file_defs->{$file->{key}}) {
          $logger->info ({
            type => 'item ignored by skip_other_files',
            value => $file->{key},
            path => $in->path->absolute,
          });
          next;
        }
        
        $self->_set_item_file_info
            ($url, $file_defs->{$file->{key}}, $in, $file, %args)
            unless $skipped; # XXX tests for skipped
        if ($args{with_props}) {
          my $pi = $file->{package_item};
          {
            last if defined $pi->{file_time};
          if (defined $res->{last_modified}) {
            my $dtp = Web::DateTime::Parser->new;
            $dtp->onerror (sub { });
            my $dt = $dtp->parse_local_date_and_time_string ($res->{last_modified});
            if (defined $dt) {
              $pi->{file_time} = $dt->to_unix_number;
              last;
            }
          }
          if (defined $res->{created}) {
            my $dtp = Web::DateTime::Parser->new;
            $dtp->onerror (sub { });
            my $dt = $dtp->parse_local_date_and_time_string ($res->{created});
            if (defined $dt) {
              $pi->{file_time} = $dt->to_unix_number;
              last;
            }
          }
          if (defined $file->{rev}) {
            $pi->{file_time} = $file->{rev}->{http_date} // $file->{rev}->{timestamp};
            last;
          }
          } # time
          $pi->{title} = $res->{name} // '';
          {
            use utf8;
            my $proto_mime = $pi->{mime} // '';
            my $ckan_mime = $res->{mimetype} // '';
            my $ckan_format = $res->{format} // '';
            $ckan_format =~ tr/A-ZＡ-Ｚａ-ｚ０-９/a-za-za-z0-9/;
            $ckan_format =~ s/^\.//;
            $ckan_format = '' if $ckan_format eq $ckan_mime;
            $proto_mime = '' if $proto_mime eq 'application/octet-stream';

            my $file_name = $res->{url};
            $file_name = $file->{rev}->{url} if defined $file->{rev};
            my $ext = '';
            if (defined $file->{rev} and $file->{rev}->{mime_filename}) {
              $file_name = $file->{rev}->{mime_filename};
            } elsif (defined $file_name) {
              $file_name =~ s{#.*}{}s;
              $file_name =~ s{\?.*}{}s;
              $ext = $1 if $file_name =~ m{\.([^./]+)$};
            }

            my $cmime;
            if ($proto_mime eq $ckan_mime or $ckan_mime eq '') {
              $cmime //= $ToComputedMIME->{$proto_mime, $ckan_format, $ext};
              $cmime //= $ToComputedMIME->{$proto_mime, $ckan_format};
            }
            if ($proto_mime eq '') {
              if (length $ckan_mime) {
                $cmime //= $ToComputedMIME->{$ckan_mime, $ckan_format};
                $cmime //= $ckan_mime;
              } else {
                $cmime //= $ToComputedMIME->{$ckan_format};
              }
            } else {
              $cmime //= $proto_mime if $proto_mime ne ($pi->{mime} // '');
            }
            if (not defined $cmime and $ckan_mime eq '' and
                $proto_mime eq '' and $ckan_format eq '' and
                $pi->{title} =~ /\.([0-9A-Za-z]+)\z/) {
              $cmime = $ExtToMIME->{lc $1};
            }
            $pi->{mime} = $cmime if defined $cmime;
          } # mime
          {
            my $title = $pi->{title};
            $title =~ tr/A-Z/a-z/;
            for my $ext (@{$MIMEToExt->{$pi->{mime} // ''} // []}) {
              if ($title =~ m{\.\Q$ext\E\z}) {
                $file->{source}->{file_name} = $pi->{title};
                last;
              }
            }
          }
        } # with_props

        push @$files, $file;

        if ($file->{type} eq 'dataset') {
          $self->_expand_dataset
              ($file, $file_defs, $in =>
               ($with_package ? $files->[0] : {}), $files, $logger,
               %args,
               error_location => {
                 path => $in->path->absolute,
               });
        } # dataset
      } # $res

      if ($with_package and $args{with_snapshot_hash}) {
        die unless @$files and $files->[0]->{type} eq 'package';
        $self->_set_snapshot_hash ($files);
      } # with_snapshot_hash

      return $files;
    });
  });
} # get_item_list

1;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
