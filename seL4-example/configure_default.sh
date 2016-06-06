#! /bin/bash

# setup Isabelle
ISABELLE=../../isabelle/bin/isabelle
if [[ -e ~/.isabelle/etc/settings ]]
then
  ISA_PLAT=$($ISABELLE env bash -c 'echo $ML_PLATFORM')
  if echo $ISA_PLAT | grep -q 64
  then
    echo Isabelle platform is $ISA_PLAT
  else
    echo Isabelle platform $ISA_PLAT not 64-bit
    echo Will not be able to build seL4 C models.
    echo Reconfigure in ~/.isabelle/etc/settings
    exit
  fi
else
  echo No Isabelle settings, setting defaults.
  mkdir -p ~/.isabelle/etc/
  cp ../../l4v/misc/etc/settings ~/.isabelle/etc/
fi
$ISABELLE components -a

function err {
  echo .. failed!
  echo Short error output:
  echo
  tail -n 20 $1
  echo
  echo "  (more error output in $1)"
  echo Need to perform manually:
  echo   cd $2
  echo   $3
  exit
}

# setup PolyML for HOL4
POLY_DIR=$(readlink -f ../../polyml)
POLY=$POLY_DIR/deploy/bin/poly
if [[ -e $POLY ]]
then
  echo PolyML already built.
else if [[ -e $POLY_DIR ]]
then
  echo PolyML present but not built in $POLY_DIR
  echo   - cd $POLY_DIR
  echo   - "./configure --prefix=$POLY_DIR/deploy && make install"
  exit
else
  echo Building PolyML in $POLY_DIR
  POLY_SRC=$($ISABELLE env bash -c 'echo $ML_SOURCES')
  cp -r $POLY_SRC $POLY_DIR
  OUT=$(readlink -f poly_output.txt)
  pushd $POLY_DIR
  (./configure --prefix=$POLY_DIR/deploy && make && make install) &> $OUT
  popd
  if [[ -e $POLY ]]
  then
    echo Built PolyML
  else
    err poly_output.txt $POLY_DIR "./configure --prefix=$POLY_DIR/deploy && make && make install"
  fi
fi fi

# setup HOL4 to use this PolyML
HOL4_DIR=$(readlink -f ../../HOL4)
if [[ -e $HOL4_DIR/bin/build ]]
then
  echo HOL4 already built
else
  echo 'Configuring HOL4'
  OUT=$(readlink -f hol4_output.txt)
  pushd $HOL4_DIR
  $POLY < tools-poly/smart-configure.sml &> $OUT
  popd
  if [[ -e $HOL4_DIR/bin/build ]]
  then
    echo 'Configured HOL4'
  else
    err hol4_output.txt $HOL4_DIR "$POLY < tools-poly/smart-configure.sml"
  fi
fi

# setup graph-refine to use CVC4 from Isabelle
SVFL=../../.solverlist
if python ../solver.py testq | grep -q 'Solver self-test succ'
then
  echo Solvers already configured.
else if [[ -e $SVFL ]]
then
  echo Solvers configured but self-test failed.
  echo Try python ../solver.py test
  echo   and adjust $SVFL to succeed.
  exit
else
  ISA_CVC4=$(isabelle env bash -c 'echo $CVC4_SOLVER')
  echo '# minimum autogenerated .solverlist' > $SVFL
  echo CVC4: online: $ISA_CVC4 --incremental --lang smt --tlimit=5000 >> $SVFL
  echo CVC4: offline: $ISA_CVC4 --lang smt >> $SVFL
  echo Configured graph-refine to use CVC4 SMT solver.
  if python ../solver.py testq | grep -q 'Solver self-test succ'
  then
    echo Self test passed.
  else
    echo Self test failed!
    echo Try python ../solver.py test
    echo   and adjust $SVFL to succeed.
    exit
  fi
fi fi

if which mlton
then
  echo MLton available.
else
  echo MLton not available or not found. 
  echo e.g. 'which mlton' should succeed.
  exit
fi


