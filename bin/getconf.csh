#!/bin/csh

# Name:   getconf.csh
# Author: wd (Wolfgang.Dobler@ncl.ac.uk)
# Date:   16-Dec-2001
# $Id: getconf.csh,v 1.61 2003-08-14 14:21:40 dobler Exp $
#
# Description:
#  Initiate some variables related to MPI and the calling sequence, and do
#  other setup needed by both start.csh and run.csh.

set debug = 1

# Set up PATH for people who don't include $PENCIL_HOME/bin by default
if ($?PENCIL_HOME) setenv PATH ${PATH}:${PENCIL_HOME}/bin

# Prevent code from running twice (and removing files by accident)
if (-e "LOCK") then
  echo ""
  echo "start.csh: found LOCK file"
  echo "This may indicate that the code is currently running in this directory"
  echo "If this is a mistake (eg after a crash), remove the LOCK file by hand:"
  echo "rm LOCK"
  # exit                        # won't work in a sourced file
  kill $$			# full-featured suicide
endif

# Are we running the MPI version?
set mpi = `egrep -c '^[ 	]*MPICOMM[ 	]*=[ 	]*mpicomm' src/Makefile.local`
# Determine number of CPUS
set ncpus = `perl -ne '$_ =~ /^\s*integer\b[^\\!]*ncpus\s*=\s*([0-9]*)/i && print $1' src/cparam.local`
echo $ncpus CPUs

# Location of executables; can be overwritten below
set start_x = "src/start.x"
set run_x   = "src/run.x"
set x_ops = ""         # arguments to both start.x and run.x

# Settings for machines with local data disks
# local_disc     = 1 means processes uses their own local scratch disc(s) for
#                    large files like var.dat, VARN, etc.
# one_local_disc = 1 means one common scratch disc for all processes
# local_binary   = 1 means copy executable to local scratch area of master node
set local_disc     = 0
set one_local_disc = 1		# probably the more common case
set local_binary   = 0
setenv SCRATCH_DIR /scratch
setenv SSH ssh
setenv SCP scp

# Any lam daemons to shutdown at the end of run.csh?
set booted_lam = 0

echo `uname -a`
set hn = `uname -n`
if ($mpi) echo "Running under MPI"
set mpirunops = ''

# Construct list of nodes, separated by colons, so it can be transported
# in an environment variable
if ($?PBS_NODEFILE) then
  setenv NODELIST \
  `cat $PBS_NODEFILE | grep -v '^#.*' | sed 's/:[0-9]*//' | xargs printf ":%s" | sed s/^://`
else
  setenv NODELIST "$hn"
endif

## ------------------------------
## Choose machine specific settings

if ($hn =~ mhd*.st-and.ac.uk) then
  echo "St Andrews machine"
  set mpirun = "dmpirun"

else if ($hn =~ *.kis.uni-freiburg.de) then
  set mpirun = /opt/local/mpich/bin/mpirun

else if ($hn =~ sleipner) then
  set mpirun = /usr/bin/poe
  set local_disc = 1
  set local_binary = 1		# (probably not needed..)
  setenv SCRATCH_DIR $SCRDIR

else if ( ($hn =~ cincinnatus*) || ($hn =~ owen*) \
          || ($hn =~ master) || ($hn =~ node*) ) then
  set mpirun = /usr/lib/lam/bin/mpirun
  set mpirunops = "-c2c -O"
#  set mpirunops = "-c2c c8-13"

set local_disc = 1
set local_binary = 0
setenv SCRATCH_DIR /var/tmp/dobler

else if (($hn =~ copson.st-and.ac.uk) || ($hn =~ comp*.st-and.ac.uk)) then
  set mpirun = /opt/score/bin/mpirun
  set mpirunops = ""
#  set mpirun = /opt/score/bin/scout 
#  set mpirunops = "-wait"

else if ($hn =~ nq* || $hn =~ ns*) then
  echo "Nordita cluster"
  if ($?PBS_NODEFILE) then
    echo "PBS job"
    cat $PBS_NODEFILE > lamhosts
    set local_disc = 1
    set local_binary = 1	# (really needed?)
  else
    echo "Non-PBS, running on `hostname`"
    echo `hostname` > lamhosts
  endif
  echo "lamnodes:"
  lamboot lamhosts >& /dev/null # discard output, or auto-test
                                # mysteriously hangs on Nq0
  set booted_lam = 1
  lamnodes
  set mpirun = /usr/bin/mpirun
  set mpirun = /opt/lam/bin/mpirun
  set mpirunops = "-O -c2c -s n0"
  if ($local_disc) then
     setenv SCRATCH_DIR "/var/tmp"
  endif

else if (($hn =~ s[0-9]*p[0-9]*) || ($hn =~ 10_[0-9]*_[0-9]*_[0-9]*)) then
  echo "Horseshoe cluster"
  if ($mpi) then
    if ($?RUNNINGMPICH) then
      set mpirunops = "-machinefile $PBS_NODEFILE"
      set mpirun = /usr/local/lib/MPICH/bin/mpirun
      set start_x=$PBS_O_WORKDIR/src/start.x
      set run_x=$PBS_O_WORKDIR/src/run.x
    else
      echo "Using LAM-MPI"
      cat $PBS_NODEFILE > lamhosts
      lamboot -v lamhosts
      set booted_lam = 1
      echo "lamnodes:"
      lamnodes
      # set mpirunops = "-O -c2c -s n0 N -v" #(direct; should be faster)
      # set mpirunops = "-O -s n0 N -lamd" #(with debug options on; is slower)
      set mpirunops = "-O -s n0 N -ger" #(with debug options on; is slower)
      set mpirun = mpirun
    endif
    setenv SCRATCH_DIR /scratch
    set local_disc = 1
    set one_local_disc = 0
    set local_binary = 1
    setenv SSH rsh 
    setenv SCP rcp
  else # (no MPI)
    echo "Batch job: non-MPI single processor run"
    cat $PBS_NODEFILE > lamhosts
    lamboot -v lamhosts 
    set booted_lam = 1
    echo "lamnodes:" 
    lamnodes
    set mpirunops = ''
    set mpirun = ''
  endif

else if ($hn == rasmussen) then
  echo "Rasmussen"
  limit stacksize unlimited
  set mpirun = 'mpirun'
  set mpirunops = ''
  set npops = ''
  set ncpus = 1

else if ($hn == hwwsr8k) then
  echo "Hitachi in Stuttgart"
  set nnodes = `echo "precision=0; ($ncpus-1)/8+1" | bc` # Hitachi-specific
  set mpirun = mpiexec
  set mpirunops = "-p multi -N $nnodes"
  set x_ops = '-Fport(nmlist(2))'
  set local_disc = 1
  set one_local_disc = 1	# (the default anyway)
  set local_binary = 0
  if (($?SCRDIR) && (-d $SCRDIR)) then
    setenv SCRATCH_DIR "$SCRDIR"
  else
    echo 'NO SUCH DIRECTORY: $SCRDIR'="<$SCRDIR> -- ABORTING"
    exit 0
  endif
  setenv SSH rsh 
  setenv SCP rcp

else if ($hn == hwwsx5) then
  echo "NEC-SX5 in Stuttgart"
  set mpirun = mpiexec

else
  echo "Generic setup; hostname is <$hn>"
  if ($mpi) echo "Use mpirun"
  set mpirun = mpirun
endif

## MPI specific setup
if ($mpi) then
  # Some mpiruns need special options
  if (`domainname` == "aegaeis") then
    set mpirunops = '-machinefile ~/mpiconf/mpihosts-martins'
  endif

  if ($mpirun =~ *mpirun*) then
    set npops = "-np $ncpus"
  else if ($mpirun =~ *mpiexec*) then
    set npops = "-n $ncpus"
  else if ($mpirun =~ *scout*) then
    set npops = "-nodes $ncpus"
  else if ($mpirun =~ *poe*) then
    set npops = "-procs $ncpus"
  else
    echo "getconf.csh: No clue how to tell $mpirun to use $ncpus nodes"
  endif

else # no MPI

  echo "Non-MPI version"
  set mpirun = ''
  set mpirunops = ''
  set npops = ''
  set ncpus = 1

endif
## End of machine specific settings
## ------------------------------

# Determine data directory (defaults to `data')
if (-r datadir.in) then
  set datadir = `cat datadir.in | sed 's/ *\([^ ]*\).*/\1/'`
else
  set datadir = "data"
endif
echo "datadir = $datadir"

# If local disc is used, write name into $datadir/directory_snap.
# This will be read by the code, if the file exists.
# Remove file, if not needed, to avoid confusion.
if ($local_disc) then
  echo $SCRATCH_DIR >$datadir/directory_snap
else
  if (-f $datadir/directory_snap) rm $datadir/directory_snap
endif

if ($local_binary) then
  set start_x = $SCRATCH_DIR/start.x
  set run_x   = $SCRATCH_DIR/run.x
endif

# Unpack NODELIST to csh array
set nodelist = `echo "$NODELIST" | sed 's/:/ /g'`

# Created subdirectories on local scratch disc (start.csh will also create
# them under $datadir/)
set subdirs = ("allprocs" "averages" "idl")
set procdirs = \
    `printf "%s%s%s\n" "for(i=0;i<$ncpus;i++){" '"proc";' 'i; }' | bc`
if ($local_disc) then
  echo "Creating directory structure on scratch disc(s)"
  foreach host ($nodelist)
    $SSH $host "cd $SCRATCH_DIR; mkdir -p $procdirs $subdirs" 
  end
endif

# Apply the SGI namelist read fix if running IRIX
set os = `uname -s`
if ($os =~ IRIX*) then
  touch SGIFIX
else
  rm -f SGIFIX
endif

if ($debug) then
  echo '$mpi          = ' "<$mpi>"
  echo '$ncpus        = ' "<$ncpus>"
  echo '$local_disc   = ' "<$local_disc>"
  echo '$local_binary = ' "<$local_binary>"
  echo '$datadir      = ' "<$datadir>"
  echo '$SCRATCH_DIR  = ' "<$SCRATCH_DIR>"
  echo '$hn           = ' "<$hn>"
  echo '$mpirun       = ' "<$mpirun>"
  echo '$mpirunops    = ' "<$mpirunops>"
  echo '$x_ops        = ' "<$x_ops>"
  echo '$NODELIST     = ' "<$NODELIST>"
  echo '$SSH          = ' "<$SSH>"
  echo '$SCP          = ' "<$SCP>"
endif

exit

# End of file getconf.csh
