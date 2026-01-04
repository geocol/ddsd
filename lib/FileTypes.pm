package FileTypes;
use strict;
use warnings;

## Common MIME types and file extensions used on Web sites, CKAN, and
## ZIP archives
##
## Sources:
## <https://wiki.suikawiki.org/n/MIME%20type>
## <https://wiki.suikawiki.org/n/CKAN%20resource>
## <https://w3c.github.io/packaged-webapps/packaging/#file-identification-table>
## <https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/MIME_types/Common_types>

my $MIMENormalize = {
  'application/x-java-archive' => 'application/java-archive',
  'application/x-jar' => 'application/java-archive',
  'application/java-byte-code' => 'application/java',
  'application/java-vm' => 'application/java',
  'application/x-httpd-java' => 'application/java',
  'application/x-java-applet' => 'application/java',
  'application/x-java-byte-code' => 'application/java',
  'application/x-java-class' => 'application/java',
  'application/x-java-vm' => 'application/java',
  'application/javascript' => 'text/javascript',
  'application/javascript; charset=utf-8' => 'text/javascript',
  'application/json; charset=utf-8' => 'application/json',
  'application/x-gzip' => 'application/gzip',
  'application/eps' => 'application/postscript',
  'application/x-eps' => 'application/postscript',
  'application/x-latex' => 'application/x-tex',
  'application/x-ndjson' => 'application/ldjson',
  'application/x-ldjson' => 'application/ldjson',
  'application/ldjson;mode=precise' => 'application/ldjson',
  'application/x-lha' => 'application/lha',
  'application/lzh' => 'application/lha',
  'application/x-lzh' => 'application/lha',
  'application/x-lzh-compressed' => 'application/lha',
  'application/x-shar' => 'application/x-sh',
  'application/sgml' => 'text/sgml',
  'application/smil' => 'application/smil+xml',
  'application/xml; charset=utf-8' => 'text/xml; charset=utf-8',
  'application/xml' => 'text/xml',
  'application/xml-external-parsed-entity' => 'text/xml-external-parsed-entity',
  'application/x-zip-compressed' => 'application/zip',
  'application/x-zip-compressed; charset=utf-8' => 'application/zip',
  'application/x-zip' => 'application/zip',
  'application/x-zip; charset=utf-8' => 'application/zip',
  'binary/octet-stream' => 'application/octet-stream',
  'audio/x-aifc' => 'audio/aiff',
  'audio/x-aiff' => 'audio/aiff',
  'audio/au' => 'audio/basic',
  'audio/mid' => 'audio/midi',
  'audio/x-mid' => 'audio/midi',
  'audio/x-midi' => 'audio/midi',
  'audio/x-wav' => 'audio/wav',
  'audio/x-wave' => 'audio/wav',
  'audio/wave' => 'audio/wav',
  'audio/vnd.wave' => 'audio/wav',
  'audio/x-mpegurl' => 'application/vnd.apple.mpegurl',
  'audio/mpegurl' => 'application/vnd.apple.mpegurl',
  'video/mpegurl' => 'application/vnd.apple.mpegurl',
  'video/x-mpegurl' => 'application/vnd.apple.mpegurl',
  'application/x-mpegurl' => 'application/vnd.apple.mpegurl',
  'audio/x-realaudio' => 'audio/x-pn-realaudio',
  'video/avi' => 'video/x-msvideo',
  'video/x-avi' => 'video/x-msvideo',
  'video/vnd.avi' => 'video/x-msvideo',
  'video/x-flv' => 'video/flv',
  'video/x-mng' => 'video/mng',
  'video/mpg' => 'video/mpeg',
  'video/x-mpg' => 'video/mpeg',
  'video/msvideo' => 'video/x-msvideo',
  'image/apng' => 'image/png',
  'image/x-bmp' => 'image/bmp',
  'image/x-ms-bmp' => 'image/bmp',
  'image/vnd.mozilla.apng' => 'image/png',
  'image/eps' => 'application/postscript',
  'image/x-eps' => 'application/postscript',
  'image/xbitmap' => 'image/xbm',
  'image/x-xbitmap' => 'image/xbm',
  'image/x-xbm' => 'image/xbm',
  'text/javascript; charset=utf-8' => 'text/javascript',
  'application/x-ms-jscript' => 'text/javascript',
  'text/json' => 'application/json',
  'text/x-json' => 'application/json',
  'text/x-perl' => 'text/perl',
  'text/pod' => 'text/perl',
  'text/perlscript' => 'text/perl',
  'application/x-perl' => 'text/perl',
  'text/x-script.perl' => 'text/perl',
  'text/x-script.perl-module' => 'text/perl',
  'text/turtle; charset=utf-8' => 'text/turtle; charset=UTF-8',
  'text/vbs' => 'text/vbscript',
  'text/xsl' => 'application/xslt+xml',
  'text/x-xslt' => 'application/xslt+xml',
  'font/eot' => 'application/vnd.ms-fontobject',
  'x-font/eot' => 'application/vnd.ms-fontobject',
  'font/opentype' => 'font/otf',
  'font/truetype' => 'font/otf',
  'font/ttf' => 'font/otf',
  'x-font/ttf' => 'font/otf',
  'application/font-sfnt' => 'font/otf',
  'font/x-woff' => 'font/woff',
  'x-font/woff' => 'font/woff',
  'application/font-woff' => 'font/woff',
  'x-world/x-vrml' => 'model/vrml',
};

sub normalize_mime_type_string ($) {
  my $m = $_[0];
  $m =~ s{\A([^;]+);\s*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=[Uu][Tt][Ff]-8\z}{$1; charset=utf-8};
  $m =~ s{^([^;\s]+)}{lc $1}e;
  $m = $MIMENormalize->{$m} // $m;
  return $m;
} # normalize_mime_type_string

sub remove_mime_type_parameters ($) {
  my $m = $_[0];
  $m =~ s{\s*;.*\z}{}gs;
  return $m;
} # remove_mime_type_parameters


my $MIMEToExts = {};
my $ExtToMIME = {};
for (
  ['image/avif' => ['avif']],
  ['image/bmp' => ['bmp']],
  ['image/vnd.dxf' => ['dxf']],
  ['image/gif' => ['gif']],
  ['image/vnd.microsoft.icon' => ['ico']],
  ['image/jpeg' => ['jpeg', 'jpg']],
  ['image/png' => ['png', 'apng']],
  ['image/tiff' => ['tiff', 'tif']],
  ['image/webp' => ['webp']],
  ['image/xbm' => ['xbm']],
  ['image/vnd.djvu' => ['djv', 'djvu']],
  ['audio/aac' => ['aac']],
  ['audio/aiff' => ['aiff', 'aif', 'aifc']],
  ['audio/basic' => ['au', 'snd']],
  ['application/vnd.apple.mpegurl' => ['m3u', 'm3u8']],
  ['audio/midi' => ['mid', 'midi']],
  ['audio/mpeg' => ['mp3']],
  ['audio/webm' => ['weba']],
  ['audio/x-pn-realaudio' => ['rm', 'ra', 'ram']],
  ['audio/x-ms-wma' => ['wma']],
  ['audio/x-ms-wax' => ['wax']],
  ['video/x-ms-asf' => ['asf', 'asx']],
  ['video/flv' => ['flv']],
  ['video/mp4' => ['mp4']],
  ['video/mpeg' => ['mpeg', 'mpg', 'mpe']],
  ['video/mng' => ['mng']],
  ['video/x-msvideo' => ['avi']],
  ['video/x-ms-wm' => ['wm']],
  ['video/x-ms-wmv' => ['wmv']],
  ['video/x-ms-wmx' => ['wmx']],
  ['video/x-ms-wvx' => ['wvx']],
  ['video/mp2t' => ['ts']],
  ['video/quicktime' => ['qt', 'mov']],
  ['video/webm' => ['webm']],
  ['text/cache-manifest' => ['appcache', 'manifest', 'm']],
  ['text/calendar' => ['ics']],
  ['text/css' => ['css']],
  ['text/csv' => ['csv']],
  ['text/event-stream' => []],
  ['text/x-h2h' => ['h2h', 'hnf']],
  ['text/x-hdml' => ['hdml', 'hdm']],
  ['text/html' => ['html', 'htm']],
  ['text/x-component' => ['htc']],
  ['text/javascript' => ['js', 'mjs']],
  ['text/markdown' => ['md']],
  ['text/n3' => ['n3']],
  ['text/perl' => ['pl', 'pm', 't', 'pod']],
  ['text/ping' => []],
  ['text/plain' => ['txt']],
  ['text/sgml' => ['sgml', 'sgm']],
  ['text/tab-separated-values' => ['tsv']],
  ['text/turtle' => ['ttl']],
  ['text/vbscript' => ['vbs']],
  ['message/rfc822' => ['822', 'eml']],
  ['application/ai' => ['ai']],
  ['application/x-abiword' => ['abw']],
  ['application/vnd.android.package-archive' => ['apk']],
  ['application/vnd.ms-htmlhelp' => ['chm']],
  ['application/vnd.dbf' => ['dbf']],
  ['application/dm' => ['dm']],
  ['application/xml-dtd' => ['dtd']],
  ['application/x-dvi' => ['dvi']],
  ['application/msword' => ['doc']],
  ['application/java' => ['class']],
  ['application/mbox' => ['mbox']],
  ['application/octet-stream' => ['dat', 'bin']],
  ['application/x-pem-file' => ['pem']],
  ['application/pkix-cert' => ['cer']],
  ['application/pdf' => ['pdf']],
  ['application/vnd.ms-powerpoint' => ['ppt']],
  ['application/postscript' => ['ps', 'eps']],
  ['application/relax-ng-compact-syntax' => ['rnc']],
  ['application/x-rpm' => ['rpm']],
  ['application/rtf' => ['rtf']],
  ['application/x-sh' => ['sh', 'shar']],
  ['application/x-shockwave-flash' => ['swf']],
  ['application/x-stuffit' => ['sit']],
  ['application/x-tex' => ['tex', 'latex']],
  ['application/vnd.visio' => ['vsd']],
  ['application/vnd.ms-excel' => ['xls', 'xlm', 'xla', 'xlc', 'xlt', 'xlw']],
  ['application/vnd.ms-excel.sheet.macroEnabled.12' => ['xlsm']],
  # exe dll com  so  iso img 
  ['application/geo+json' => ['geojson', 'json'], ['geojson']],
  ['application/json' => ['json']],
  ['application/ld+json' => ['jsonld', 'json'], ['jsonld']],
  ['application/manifest+json' => ['webmanifest', 'json'], ['webmanifest']],
  ['text/xml' => ['xml', 'xbl', 'cdf', 'rng', 'xsd']],
  ['text/xml-external-parsed-entity' => ['ent']],
  ['image/svg+xml' => ['svg', 'xml'], ['svg']],
  ['application/atom+xml' => ['atom', 'xml'], ['atom']],
  ['application/vnd.google-earth.kml+xml' => ['kml', 'xml'], ['kml']],
  ['application/vnd.google-earth.kmz' => ['kmz']],
  ['application/rdf+xml' => ['rdf', 'foaf', 'xml'], ['rdf', 'foaf']],
  ['application/rdf+xml' => ['rdf', 'xml'], ['rdf']],
  ['application/rss+xml' => ['rss', 'xml'], ['rss']],
  ['application/smil+xml' => ['smil', 'smi', 'sml', 'xml'], ['smil', 'smi', 'sml']],
  ['application/xhtml+xml' => ['xhtml', 'xht', 'xhtm', 'xml'], ['xhtml', 'xht', 'xhtm']],
  ['application/xslt+xml' => ['xsl', 'xslt', 'xml'], ['xsl', 'xslt']],
  ['application/vnd.mozilla.xul+xml' => ['xul', 'xml'], ['xul']],
  ['text/vnd.wap.wml' => ['wml']],
  ['application/x-bzip2' => ['bz2']],
  ['application/vnd.ms-cab-compressed' => ['cab']],
  ['application/gzip' => ['gz', 'tgz', 'svgz']],
  ['application/mac-binhex40' => ['hqx']],
  ['application/lha' => ['lzh', 'lha']],
  ['application/x-tar' => ['tar']],
  ['application/vnd.rar' => ['rar']],
  ['application/x-xz' => ['xz']],
  ['application/x-compress' => ['z']],
  ['application/zstd' => ['zstd']],
  ['application/zip' => ['zip']],
  ['application/epub+zip' => ['epub']],
  ['application/java-archive' => ['jar']],
  ['application/vnd.openxmlformats-officedocument.wordprocessingml.document' => ['docx']],
  ['application/vnd.openxmlformats-officedocument.presentationml.presentation' => ['pptx']],
  ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => ['xlsx']],
  ['application/vnd.oasis.opendocument.presentation' => ['odp']],
  ['application/vnd.oasis.opendocument.spreadsheet' => ['ods']],
  ['application/vnd.oasis.opendocument.text' => ['odt']],
  ['application/x-xpinstall' => ['xpi']],
  ['application/widget' => ['wgt']],
  ['application/vnd.ms-fontobject' => ['eot']],
  ['font/otf' => ['ttf', 'otf', 'ttc', 'otc']],
  ['application/font-tdpfr' => ['pfr']],
  ['font/woff' => ['woff']],
  ['font/woff2' => ['woff2']],
  ['model/vrml' => ['wrl']],
) {
  my ($mime, $exts) = @{$_};
  my $exts2 = $_->[2] // $exts;
  
  $MIMEToExts->{$mime} = {map { $_ => 1 } @$exts};
  for my $ext (@$exts2) {
    $ExtToMIME->{$ext} = $mime;
  }
}

my $IsZipMIMEType = {map { $_ => 1 } qw(
  application/zip
  application/epub+zip
  application/java-archive
  application/vnd.openxmlformats-officedocument.wordprocessingml.document
  application/vnd.openxmlformats-officedocument.presentationml.presentation
  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  application/vnd.oasis.opendocument.presentation
  application/vnd.oasis.opendocument.spreadsheet
  application/vnd.oasis.opendocument.text
  application/x-xpinstall
  application/widget
)};

my $IsJsonMIMEType = {map { $_ => 1 } qw(
  application/json
)};
my $IsJsonLinesMIMEType = {map { $_ => 1 } qw(
  application/ldjson
  application/city+json-seq
)};


sub get_mime_type_from_file_name ($) {
  if ($_[0] =~ /\.([0-9A-Za-z]+)\z/) {
    return $ExtToMIME->{lc $1}; # or undef
  } else {
    return undef;
  }
} # get_mime_type_from_file_name

sub is_file_name_for_mime_type ($$) {
  my ($title, $mime) = @_;
  $title =~ s{\.([0-9A-Za-z]+)\z}{} or return 0;
  my $actual_ext = $1;
  $actual_ext =~ tr/A-Z/a-z/;
  return (($MIMEToExts->{$mime} or {})->{$actual_ext});
} # is_file_name_for_mime_type

sub force_zip_mime_type ($) {
  my $mime = $_[0]; # normalized
  my $type = remove_mime_type_parameters $mime;
  return $mime if $IsZipMIMEType->{$mime};
  return $mime if $type =~ /\+zip\z/;
  return 'application/zip';
} # force_zip_mime_type

1;

=head1 LICENSE

Copyright 2024-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
