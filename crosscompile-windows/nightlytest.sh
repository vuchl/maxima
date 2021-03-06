#!/bin/bash

# Script for nightly testruns
# should be copied to a private location (~/bin), so that
# git changes to that script can be reviewed before.
#
# a working directory is ~/maxima-test

MAXIMAGITREPOSITORY=https://git.code.sf.net/p/maxima/code
# if there is already a local repository (from the nightly Windows build),
# clone from that git repository
test -d ~/maxima-code/.git && MAXIMAGITREPOSITORY=~/maxima-code

mkdir -p ~/maxima-test

cd ~/maxima-test || exit

rm -rf -- * .git*


git clone $MAXIMAGITREPOSITORY .

export PATH=/opt/ccl:$PATH


./bootstrap >logfile-bootstrap.txt 2>&1

./configure --enable-clisp --enable-ecl --enable-sbcl --enable-gcl --enable-ccl64 --with-ccl64=lx86cl64 --enable-cmucl --with-cmucl=/opt/cmucl-21b/bin/lisp --with-cmucl-runtime=/opt/cmucl-21b/bin/lisp --enable-acl --with-acl=/opt/acl100express/alisp --prefix=$(pwd)/installroot >logfile-configure.txt 2>&1

make VERBOSE=1 >logfile-make.txt 2>&1
make pdf VERBOSE=1 >logfile-makepdf.txt 2>&1
make install VERBOSE=1 >logfile-makeinstall.txt 2>&1
make dist VERBOSE=1 >logfile-makedist.txt 2>&1

~/maxima-test/installroot/bin/maxima --run-string="build_info();" >logfile-buildinfo.txt
for lisp in clisp ecl sbcl gcl ccl64 cmucl acl ; do
      ~/maxima-test/installroot/bin/maxima --lisp=$lisp --run-string="run_testsuite();" >logfile-testsuite-$lisp.txt
      echo "$lisp summary" >>logfile-summary.txt
      sed -n -e '/^Error summary\|^No unexpected errors/,$p' logfile-testsuite-$lisp.txt >>logfile-summary.txt
      echo >>logfile-summary.txt
      echo >>logfile-summary.txt
      echo >>logfile-summary.txt
done

# Test ABCL
# currently not possible using a ./configure option, so do the Lisp only build.
# (and testing the Lisp build system does not hurt...)

ABCL_JAR=/opt/abcl-bin-1.4.0/abcl.jar
JAVA=$(which java)
ABCL="$JAVA -server -Xrs -cp $ABCL_JAR org.armedbear.lisp.Main"

(
cat <<ABCL1
(load "configure.lisp")
(configure :interactive nil)
(quit)
ABCL1
) >/tmp/abcl-configure
$ABCL --noinit --load /tmp/abcl-configure
cd src
(
cat <<ABCL2
(load "maxima-build.lisp")
(maxima-compile)
(quit)
ABCL2
) >/tmp/abcl-compile
$ABCL --noinit --load /tmp/abcl-compile
(
cat <<ABCL3
(load "maxima-build.lisp")
(maxima-load)
(cl-user::run)
ABCL3
) >/tmp/abcl-run
echo "run_testsuite(); quit();" | $ABCL --noinit --load /tmp/abcl-run >../logfile-testsuite-abcl.txt
cd ..

echo "abcl summary" >>logfile-summary.txt
sed -n -e '/^Error summary\|^No unexpected errors/,$p' logfile-testsuite-abcl.txt >>logfile-summary.txt
echo >>logfile-summary.txt
echo >>logfile-summary.txt
echo >>logfile-summary.txt


scp -i ~/.ssh/maximakopierkey ~/maxima-test/logfile-*.txt maxima@ns1.dautermann.at:/var/www/wolfgang.dautermann.at/maxima/nightlybuild/
