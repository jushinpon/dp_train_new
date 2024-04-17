use strict;
use warnings;
use Cwd;
use Data::Dumper;

my @virial =`grep -v "#" *.out |awk '{print \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9}'`;
chomp @virial;
map { s/^\s+|\s+$//g; } @virial;
my @all_data;
for my $virial_data(@virial){
    my @virial_data_split = split(/ /,$virial_data);
    for(@virial_data_split){
        my $number = sprintf("%.10f", $_);
        $number = abs($number);
        push @all_data,$number;
    }
}

my %counts;
my $step = 30; #設定間格
my $max = 450; #設最大值
for (my $i = 1; $i < $max; $i += $step) {
    my $range = $i . "-" . ($i + $step - 1);
    $counts{$range} = 0;  
}

foreach my $num (@all_data) {
    for (my $i = 1; $i < $max; $i += $step) {
        if ($num >= $i && $num < $i + $step) {
            my $range = $i . "-" . ($i + $step - 1);
            $counts{$range}++;
            last;
        }
    }
}

foreach my $range (sort { 
    my ($a_start) = $a =~ /^(\d+)-\d+$/;  
    my ($b_start) = $b =~ /^(\d+)-\d+$/;
    $a_start <=> $b_start  
} keys %counts) {
    print "Range $range has $counts{$range} items.\n";
}


