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
my $datafile_name = "P";
my @path = `find $currentPath/initial/*_*-* -maxdepth 1 -type d -name "*"`;
#print @path;
chomp @path;
for my $path(@path){
    my @outfile = sort `find $path  -maxdepth 2 -name "*.sout"`;
    my $outfile_number = @outfile;
    print "@outfile";
    chdir("$path");
    my @datafile = `cat $datafile_name.data`;
    my @atoms_number = grep {if(m/\s+(\d+)\s+\w*/gm){$_ = $1;}} @datafile;
    for (0..$outfile_number-1)
    {
    my @sout = `cat $outfile[$_]`;
    my @totalE = grep {if(m/!+[total energy]+\s+\=+\s+(\-+\d+\.+\d+)\s+\w*/gm){$_ = $1;}} @sout;
    my @deal_totalE = map {($_ / $atoms_number[0]) * 13.60568496} @totalE;
    print "@deal_totalE\n";
    }
}
