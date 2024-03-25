#!/bin/sh
#sed_anchor01
#SBATCH --output=dp01.out
#SBATCH --job-name=dp01
#SBATCH --nodes=1
##SBATCH --ntasks-per-node=8
#SBATCH --partition=debug
#SBATCH --ntasks-per-node=12
##SBATCH --exclude=node18,node20
export LD_LIBRARY_PATH=/opt/mpich-4.0.3/lib:$LD_LIBRARY_PATH
export PATH=/opt/mpich-4.0.3/bin:$PATH
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin:$LD_LIBRARY_PATH
#export PATH=/opt/mpich-3.4.2/bin:$PATH

#mpiexec_anchor
mpiexec /opt/QEGCC_MPICH4.0.3/bin/pw.x -in dft_script.in
rm -rf pwscf.save
sleep 60
echo "Done" > dft_done.txt
