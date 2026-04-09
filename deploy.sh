#!/bin/bash
set -e

REGISTRY="sjc.vultrcr.com/gentle"
IMAGE_NAME="energiemix-nl"
SERVER="gentle5.gentle-innovations.nl"
SERVER_PATH="/home/docker/energiemix-nl"
URL="https://energiemix.gentle-innovations.nl"

echo "Building linux/amd64 image and pushing to $REGISTRY..."
docker buildx build \
  --platform linux/amd64 \
  -t "$REGISTRY/$IMAGE_NAME:latest" \
  --push \
  .

echo "Uploading compose file to $SERVER..."
scp compose.prod.yaml "$SERVER:$SERVER_PATH/compose.yaml"

echo "Pulling and restarting on $SERVER..."
ssh "$SERVER" "cd $SERVER_PATH && sudo docker compose pull && sudo docker compose up -d"

echo "Pruning old images on $SERVER..."
ssh "$SERVER" "sudo docker image prune -f"

echo ""
echo "Done. Live at: $URL"
