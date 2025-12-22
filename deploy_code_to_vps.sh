#!/bin/bash

# Script to deploy code changes to VPS
# This will commit, push to git, and pull on VPS

set -e

VPS_IP="152.42.240.220"
PROJECT_DIR="/var/www/auditra"
BRANCH="Pasidu"

echo "🚀 Deploying code changes to VPS..."

# Step 1: Commit and push changes (run from local machine)
echo "📝 Step 1: Committing and pushing changes to Git..."
echo "⚠️  Note: You need to commit and push your changes first!"
echo ""
echo "Run these commands on your local machine:"
echo "  git add ."
echo "  git commit -m 'Add auto-create client/agent accounts with email notifications'"
echo "  git push origin $BRANCH"
echo ""
read -p "Have you committed and pushed your changes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Please commit and push your changes first, then run this script again."
    exit 1
fi

# Step 2: Pull changes on VPS
echo "📥 Step 2: Pulling latest code on VPS..."
ssh root@$VPS_IP << EOF
    cd $PROJECT_DIR
    git fetch origin
    git checkout $BRANCH
    git pull origin $BRANCH
    echo "✅ Code updated on VPS"
EOF

# Step 3: Run migrations
echo "🔄 Step 3: Running database migrations..."
ssh root@$VPS_IP << EOF
    cd $PROJECT_DIR/backend
    source venv/bin/activate
    python manage.py migrate
    echo "✅ Migrations completed"
EOF

# Step 4: Collect static files
echo "📁 Step 4: Collecting static files..."
ssh root@$VPS_IP << EOF
    cd $PROJECT_DIR/backend
    source venv/bin/activate
    python manage.py collectstatic --noinput
    echo "✅ Static files collected"
EOF

# Step 5: Restart services
echo "🔄 Step 5: Restarting Django service..."
ssh root@$VPS_IP "supervisorctl restart auditra"

# Step 6: Verify
echo "✅ Step 6: Verifying service status..."
ssh root@$VPS_IP "supervisorctl status auditra"

echo ""
echo "✅ Code deployment complete!"
echo "All changes have been deployed to VPS."

