use strict;
use warnings;
use Cwd;
use JSON::PP;
use List::Util qw(min max);
use POSIX;
use lib '.';
use Expect;
use Data::Dumper;
my $currentPath = getcwd();
my @path = `find $currentPath/initial/ -maxdepth 1 -type d -name "*"`;
chomp @path;
my @path_name = grep {if(m/\/+\w+\/+\w*+\/+\w*+\/+\w*+\/+\w*+\/+(\w*+\-+\d*)/gm){$_ = $1;}} @path; ##Adjust the regex according to your own path format!!!
open my $txt1,">$currentPath/initial/ini_path.txt" or die ("Can't open ini_path.txt");
my $path_number = scalar @path_name;
for (0..$path_number-1)
{
    print $txt1 "\""."$path_name[$_]\"".',';
}
close ($txt1);
open my $txt2,"<$currentPath/initial/ini_path.txt" or die ("Can't open ini_path.txt");
my @txtfile = <$txt2>;
close ($txt2);
chomp @txtfile;
my @in_txt = map (($_ =~ m/(\"\w+\-+\d+\"+)\,+/gm), @txtfile); ##Adjust the regex according to your own path format!!!
my $connect = join(",", @in_txt);
open my $txt3,">$currentPath/initial/ini_path.txt" or die ("Can't open ini_path.txt");
print $txt3 "$connect";
