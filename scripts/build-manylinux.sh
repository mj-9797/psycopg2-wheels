#!/bin/bash

# Create manylinux1 wheels for psycopg2
#
# Run this script with something like:
#
# docker run --rm -v `pwd`:/build quay.io/pypa/manylinux1_x86_64 /build/scripts/build-manylinux.sh
# docker run --rm -v `pwd`:/build quay.io/pypa/manylinux1_i686 linux32 /build/scripts/build-manylinux.sh
#
# Tests run against a postgres on the host. Use -e PSYCOPG_TESTDB_USER=... etc
# to configure tests run.

set -e -x

# Install postgres packages for build and testing
# This doesn't work:
# rpm -Uvh "http://yum.postgresql.org/9.5/redhat/rhel-5-x86_64/pgdg-redhat95-9.5-3.noarch.rpm"
wget -O "/tmp/pgdg.rpm" "https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-5-x86_64/pgdg-centos95-9.5-3.noarch.rpm"
rpm -Uv "/tmp/pgdg.rpm"
yum install -y postgresql95-devel

# Make pg_config available
export PGPATH=/usr/pgsql-9.5/bin/
export PATH="$PGPATH:$PATH"

# Find psycopg version
export VERSION=$(grep -e ^PSYCOPG_VERSION /build/psycopg2/setup.py | sed "s/.*'\(.*\)'/\1/")
export DISTDIR="/build/psycopg2/dist/psycopg2-$VERSION"

# Create the wheel packages
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" wheel /build/psycopg2/ -w /build/psycopg2/wheels/
done

# Bundle external shared libraries into the wheels
for WHL in /build/psycopg2/wheels/*.whl; do
    auditwheel repair "$WHL" -w "$DISTDIR"
done

# Make sure libpq is not in the system
yum remove -y postgresql95-devel

# Connect to the host to test. Use 'docker -e' to pass other variables
export PSYCOPG2_TESTDB_HOST=$(ip route show | awk '/default/ {print $3}')

# Install packages and test
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" install psycopg2 --no-index -f "$DISTDIR"
    "${PYBIN}/python" -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
done