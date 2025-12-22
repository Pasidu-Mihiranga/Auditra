#!/bin/bash
# Update PostgreSQL password for postgres user

sudo -u postgres psql << EOF
ALTER USER postgres WITH PASSWORD 'Sasi2003##';
\q
EOF

echo "PostgreSQL password updated successfully"

