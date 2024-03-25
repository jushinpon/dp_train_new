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
my @path = `find $currentPath/all_npy/initial/*_*-* -maxdepth 0 -type d -name "*"`;
#print @path;
chomp @path;
for my $path(@path){
    my @Erawfile = sort `find $path  -maxdepth 2 -name "energy.raw"`;
    my $Erawfile = @Erawfile;
    print "@Erawfile";
    for (0..$Erawfile-1)
    {
    my @energy_raw = `cat $Erawfile[$_]`;
    my @Eraw = grep {if(m/([+-]?+\d+\.+\d*)/gm){$_ = $1;}} @energy_raw;
    my $Eraw = @Eraw;
    for (0..$Eraw-1)
    {
        if ( $Eraw[$_] < 0 )
        {
            print "$Eraw[$_] -->  OK\n";
            }
            if ( $Eraw[$_] > 0 ) 
        {
            print "$Eraw[$_] -->  NO\n";
            }
    }
    }
}
