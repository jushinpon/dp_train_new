my $keyword = "Mn_mp";
my @scancel_id = `squeue -u zhi1|grep -v JOBID|awk '{print \$1}'`;
map { s/^\s+|\s+$//g; } @scancel_id;
for (@scancel_id){
    my @temp = `scontrol show job $_|grep "$keyword"`;
    if(@temp){
        print "Job ID $_ has the keyword\n";
        #`scancel $_`; If you want to cancel this job with the keyword
    }

}
