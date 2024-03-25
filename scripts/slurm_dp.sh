#!/bin/sh
#sed_anchor01
#SBATCH --output=dp01.out
#SBATCH --job-name=dp01
#SBATCH --nodes=1
##SBATCH --ntasks-per-node=8
#SBATCH --partition=All
##SBATCH --ntasks-per-node=12
##SBATCH --reservation=GPU_test
##SBATCH --exclude=node18,node20
##SBATCH --gres=gpu:0 
source activate deepmd-cpu

threads=`lscpu|grep "^CPU(s):" | sed 's/^CPU(s): *//g'`
export OMP_NUM_THREADS=$threads
export KMP_AFFINITY=granularity=fine,compact,1,0
export KMP_BLOCKTIME=0
export KMP_SETTINGS=TRUE

#sed_anchor02
dp train Template.json
#sed_anchor03
dp freeze -o graph4.pb
#cp lcurve.out lcurve_ori.out
##sed_anchor04
#dp compress -i graph.pb -o graph-compress.pb
##sed_anchor05
#dp train input.json --init-frz-model graph-compress.pb
sleep 60
echo "Done" > train_done.txt
