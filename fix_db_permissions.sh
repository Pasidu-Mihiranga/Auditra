#!/bin/bash
# Fix PostgreSQL permissions for auditra_user

sudo -u postgres psql << EOF
-- Grant schema permissions
GRANT ALL ON SCHEMA public TO auditra_user;
ALTER SCHEMA public OWNER TO auditra_user;

-- Grant database permissions
GRANT ALL PRIVILEGES ON DATABASE auditra_db TO auditra_user;

-- For PostgreSQL 15+, ensure user can create objects
ALTER DATABASE auditra_db OWNER TO auditra_user;
EOF

