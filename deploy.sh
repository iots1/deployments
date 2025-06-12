#!/bin/bash

set -e

# Current version (this will be updated automatically after a successful deploy)
version="0.0.0.1" # Quoted for consistency and best practice (Main/Pro)
version_dev="0.0.0.1" # Quoted for consistency and best practice (Develop/Dev)

# --- Step 1: Define variables ---
PROVIDER="registry.gitlab.com"   
REPO="repository_name"
ORGANIZATION_PROD="user_for_gitlab" # This is for the GitLab registry login, usually consistent

# GitLab Access Token (for pushing to GitLab registry)
# It's highly recommended to use environment variables for sensitive tokens in CI/CD.
# The following line uses a fallback default if the environment variable is not set.
GITLAB_ACCESS_TOKEN="${GITLAB_ACCESS_TOKEN:-example_access_token}"

# === Portainer Deployment Control ===
# Set to "true" to enable Portainer-related deployment steps (login, force pull, webhook).
# Set to "false" to skip these steps.
ENABLE_PORTAINER_DEPLOYMENT="${ENABLE_PORTAINER_DEPLOYMENT:-false}" # Enabled by default

# === Protainer Configuration for PRODUCTION (main branch) ===
PORTAINER_URL_PRO="${PORTAINER_URL_PRO:-https://portainer.example.com}" # Example: A production Protainer instance
PORTAINER_USER_PRO="${PORTAINER_USER_PRO:-example_user}" # Dedicated production user
PORTAINER_PASS_PRO="${PORTAINER_PASS_PRO:-example_pass}" # Dedicated production password
PORTAINER_ENDPOINT_ID_PRO="${PORTAINER_ENDPOINT_ID_PRO:-1}" # Example: A different endpoint ID for production value is number
WEBHOOK_URL_PRO="${WEBHOOK_URL_PRO:-https://protainer.example.com/api/webhooks/prod-webhook-id}" # Pro webhook for service 
X_REGISTRY_AUTH_PRO="${X_REGISTRY_AUTH_PRO:-example_key}" # Registry Auth for PRO Portainer (might be different if pro uses a different registry config) example eyJyZWdpc3RyeUlkIjoyfQ==

# === Portainer Configuration for DEVELOPMENT (develop branch) ===
PORTAINER_URL_DEV="${PORTAINER_URL_DEV:-https://portainer-dev.example.com}" # Your current dev Portainer
PORTAINER_USER_DEV="${PORTAINER_USER_DEV:-example_user}" # Your current dev user
PORTAINER_PASS_DEV="${PORTAINER_PASS_DEV:-example_pass}" # Your current dev password
PORTAINER_ENDPOINT_ID_DEV="${PORTAINER_ENDPOINT_ID_DEV:-1}" # Your current dev endpoint ID
WEBHOOK_URL_DEV="${WEBHOOK_URL_DEV:-https://portainer-dev.example.com/api/webhooks/dev-webhook-id}" # Your current dev webhook 
X_REGISTRY_AUTH_DEV="${X_REGISTRY_AUTH_DEV:-example_key}" # Registry Auth for DEV Portainer

# --- Dynamic Portainer Variable Assignment ---
PORTAINER_URL=""
PORTAINER_USER=""
PORTAINER_PASS=""
PORTAINER_ENDPOINT_ID=""
WEBHOOK_URL=""
X_REGISTRY_AUTH=""

BRANCH=$(git rev-parse --abbrev-ref HEAD) # More robust way to get current branch

# --- Files to update with the new version ---
VERSION_FILES=(
    "package.json"
    # "src/app.service.ts"
)

# --- Step 0: Pre-flight Checks (New Step) ---
echo "⚙️  Performing pre-flight checks..."

# Check for required commands
for cmd in git docker curl jq sed; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Error: Required command '$cmd' is not found. Please install it and try again."
        exit 1
    fi
done
echo "✅ All required commands found."

# --- Step 2: Ask for new version and assign Portainer variables ---
input_version="" # Initialize input_version
current_script_version="" # To store the version in the script itself


# Optional when build project in host before build docker
# rm -rf .next
# git pull
# npm install
# npm run build

if [[ "$BRANCH" == "main" ]]; then
    current_script_version="$version"
    read -p "Enter new production version (current: $current_script_version): " input_version

    PORTAINER_URL="$PORTAINER_URL_PRO"
    PORTAINER_USER="$PORTAINER_USER_PRO"
    PORTAINER_PASS="$PORTAINER_PASS_PRO"
    PORTAINER_ENDPOINT_ID="$PORTAINER_ENDPOINT_ID_PRO"
    WEBHOOK_URL="$WEBHOOK_URL_PRO"
    X_REGISTRY_AUTH="$X_REGISTRY_AUTH_PRO"

    echo "🎯 Deploying to PRODUCTION (protainer) environment."
elif [[ "$BRANCH" == *"develop"* ]]; then
    current_script_version="$version_dev"
    read -p "Enter new develop version (current: $current_script_version): " input_version

    PORTAINER_URL="$PORTAINER_URL_DEV"
    PORTAINER_USER="$PORTAINER_USER_DEV"
    PORTAINER_PASS="$PORTAINER_PASS_DEV"
    PORTAINER_ENDPOINT_ID="$PORTAINER_ENDPOINT_ID_DEV"
    WEBHOOK_URL="$WEBHOOK_URL_DEV"
    X_REGISTRY_AUTH="$X_REGISTRY_AUTH_DEV"

    echo "🎯 Deploying to DEVELOPMENT (portainer-dev) environment."
else
    echo "❌ Branch '$BRANCH' is not configured for deployment. Exiting."
    exit 1
fi

if [[ -z "$input_version" ]]; then
    echo "❌ Version input is required. Exiting."
    exit 1
fi

# Basic version format validation (e.g., semantic versioning)
if ! [[ "$input_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "❌ Invalid version format '$input_version'. Please use semantic versioning (e.g., 1.0.0 or 1.0.0.1)."
    exit 1
fi

# --- Step 3: Ensure Docker is running ---
echo "🔍 Checking if Docker is running..."
RETRY=0
MAX_RETRY=10 # Increased max retries
until docker info >/dev/null 2>&1; do
    ((RETRY++))
    if [[ $RETRY -ge $MAX_RETRY ]]; then
        echo "❌ Docker is not running after multiple attempts. Please start Docker and try again."
        exit 1
    fi
    echo "⏳ Docker not ready yet. Retrying ($RETRY/$MAX_RETRY) in 5 seconds..." # Increased sleep
    sleep 5
done
echo "✅ Docker is running."

echo "🔐 Logging into Docker registry: $PROVIDER..."
if ! docker login "$PROVIDER" -u "$ORGANIZATION_PROD" -p "$GITLAB_ACCESS_TOKEN"; then
    echo "❌ Docker login failed. Please check your credentials and try again."
    exit 1
fi
echo "✅ Docker login successful."

IMAGE_BASE="$PROVIDER/$ORGANIZATION_PROD/$REPO"

# --- Step 4: Determine tag ---
LATEST_TAG="" # Initialize LATEST_TAG
IMAGE_TAG="$input_version" # Always tag with the specific version

if [[ "$BRANCH" == "main" ]]; then
    LATEST_TAG="latest"
elif [[ "$BRANCH" == *"develop"* ]]; then
    LATEST_TAG="develop"
fi

# --- Step 5: Update version in project files ---
echo "📝 Updating version in project files..."
# Check if files exist before attempting to sed them
for file in "${VERSION_FILES[@]}"; do # Loop through the array
    if [[ ! -f "$file" ]]; then
        echo "❌ Error: Required project file '$file' not found. Cannot update version."
        exit 1
    fi
done

# Apply sed replacements based on file content
for file in "${VERSION_FILES[@]}"; do
    case "$file" in
        "package.json")
            sed -i.bak "s|\"version\": \".*\"|\"version\": \"$input_version\"|" "$file"
            ;;
        # "src/app.service.ts")
        #     sed -i.bak "s|return 'My API v\..*';|return 'My API v.$input_version';|" "$file"
        #     ;;
        *)
            echo "⚠️  Warning: No specific sed rule for file '$file'. Skipping version update for this file."
            ;;
    esac
done

# Clean up .bak files
if ! find . -maxdepth 1 -name "*.bak" -exec rm {} +; then
    echo "⚠️  Warning: Could not remove all .bak files. Manual cleanup may be needed."
fi
echo "✅ Project files updated."

# --- Step 6: Build and push Docker image ---
echo "🔧 Building Docker image: $IMAGE_BASE:$IMAGE_TAG and $IMAGE_BASE:$LATEST_TAG..."
BUILD_PLATFORM=""
[[ "$OSTYPE" == "darwin"* ]] && BUILD_PLATFORM="--platform=linux/amd64."

# Build with both specific version tag and latest/develop tag
if ! docker build -f Dockerfile -t "$IMAGE_BASE:$IMAGE_TAG" -t "$IMAGE_BASE:$LATEST_TAG" "$BUILD_PLATFORM" .; then
    echo "❌ Docker build failed. Exiting."
    exit 1
fi
echo "✅ Docker image built successfully."

echo "⬆️  Pushing Docker images..."
if ! docker push "$IMAGE_BASE:$IMAGE_TAG"; then
    echo "❌ Docker push of specific version tag failed. Exiting."
    exit 1
fi
echo "✅ Pushed $IMAGE_BASE:$IMAGE_TAG"

if ! docker push "$IMAGE_BASE:$LATEST_TAG"; then
    echo "❌ Docker push of latest/develop tag failed. Exiting."
    exit 1
fi
echo "✅ Pushed $IMAGE_BASE:$LATEST_TAG"

echo "🗑️  Cleaning up local Docker images..."
docker rmi "$IMAGE_BASE:$IMAGE_TAG" || echo "⚠️  Warning: Could not remove local image $IMAGE_BASE:$IMAGE_TAG"
docker rmi "$IMAGE_BASE:$LATEST_TAG" || echo "⚠️  Warning: Could not remove local image $IMAGE_BASE:$LATEST_TAG"
echo "✅ Local Docker images cleaned up."

# --- Step 7 & 8: Portainer Login, Force Pull, and Webhook Trigger (Conditional) ---
if [[ "$ENABLE_PORTAINER_DEPLOYMENT" == "true" ]]; then
    echo "--- Portainer Deployment Steps (Enabled) ---"

    echo "🔐 Logging in to Portainer at $PORTAINER_URL..."
    ACCESS_TOKEN=$(curl -s -X POST "$PORTAINER_URL/api/auth" \
      -H "Content-Type: application/json" \
      -d '{"username": "'"$PORTAINER_USER"'", "password": "'"$PORTAINER_PASS"'"}' | jq -r .jwt)

    if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
      echo "❌ Failed to authenticate with Portainer. Check PORTAINER_USER and PORTAINER_PASS for $BRANCH branch."
      exit 1
    fi
    echo "✅ Portainer login successful."

    echo "🚚 Forcing image pull via Portainer Docker API for image: $IMAGE_BASE:$LATEST_TAG..."

    IMAGE_NAME_TO_PULL="$IMAGE_BASE:$LATEST_TAG"

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$PORTAINER_URL/api/endpoints/$PORTAINER_ENDPOINT_ID/docker/images/create?fromImage=$IMAGE_NAME_TO_PULL" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H 'Accept: application/json, text/plain, */*' \
      -H 'Content-Type: application/json' \
      -H "X-Registry-Auth: $X_REGISTRY_AUTH" \
      -d "{
        \"fromImage\": \"$IMAGE_NAME_TO_PULL\"
      }")

    if [[ "$HTTP_RESPONSE" -ge 200 && "$HTTP_RESPONSE" -lt 300 ]]; then
        echo "✅ Image pull command sent to Portainer successfully (HTTP $HTTP_RESPONSE)."
    else
        echo "❌ Failed to send image pull command to Portainer. HTTP Status: $HTTP_RESPONSE"
        echo "   Ensure Portainer Endpoint ID ($PORTAINER_ENDPOINT_ID) and Docker API access are correct for $BRANCH branch."
        exit 1
    fi

    echo "🚀 Triggering Portainer webhook for stack redeploy at $WEBHOOK_URL..."
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL")

    if [[ "$HTTP_RESPONSE" -ge 200 && "$HTTP_RESPONSE" -lt 300 ]]; then
        echo "✅ Webhook triggered successfully (HTTP $HTTP_RESPONSE)."
    else
        echo "❌ Failed to trigger webhook. HTTP Status: $HTTP_RESPONSE"
        echo "   Ensure WEBHOOK_URL is correct and accessible for $BRANCH branch."
        exit 1
    fi
    echo "--- Portainer Deployment Steps (Completed) ---"
else
    echo "--- Portainer Deployment Steps (Skipped as ENABLE_PORTAINER_DEPLOYMENT is not 'true') ---"
fi


# --- Step 9: Update version in this script ---
echo "🔄 Updating version in this deployment script..."
if [[ "$BRANCH" == "main" ]]; then
    sed -i.bak "s/^version=.*/version=\"$input_version\"/" "$0"
elif [[ "$BRANCH" == *"develop"* ]]; then
    sed -i.bak "s/^version_dev=.*/version_dev=\"$input_version\"/" "$0"
fi
rm "$0.bak" || echo "⚠️  Warning: Could not remove original script backup."
echo "✅ Script version updated."

# --- Step 10: Git commit and tag (only for main) ---
if [[ "$BRANCH" == "main" ]]; then
    echo "--- Git Operations (Commit, Push, Tag) ---"
    read -p "❓ Proceed with Git commit, push to main, and tag push? (y/N): " confirm_git
    if ! [[ "$confirm_git" =~ ^[yY]$ ]]; then
        echo "⏭️  Git operations skipped. Deployment process ended."
        exit 0 # Exit successfully as user chose to skip
    fi

    echo "💾 Committing version updates..."
    # Ensure all relevant files are added
    # Use the VERSION_FILES array here
    git add "${VERSION_FILES[@]}" "$0" # Add all files from the array plus the script itself
    if ! git commit -m "chore: Bump version to $input_version"; then
        echo "❌ Git commit failed. Check for uncommitted changes or merge conflicts."
        exit 1
    fi
    echo "✅ Changes committed."

    echo "Pushing changes to origin/main..."
    if ! git push origin main; then
        echo "❌ Git push to main failed. Ensure your local branch is up to date."
        exit 1
    fi
    echo "✅ Pushed to origin/main."

    GIT_TAG="v$input_version"
    echo "🏷️  Tagging release: $GIT_TAG..."
    if ! git tag -a "$GIT_TAG" -m "Release $GIT_TAG"; then
        echo "❌ Git tag failed. Tag '$GIT_TAG' might already exist."
        exit 1
    fi
    echo "✅ Tagged $GIT_TAG."

    echo "Pushing tag to origin..."
    if ! git push origin "$GIT_TAG"; then
        echo "❌ Git push of tag failed. Ensure your permissions are correct."
        exit 1
    fi
    echo "✅ Pushed tag to origin."
    echo "--- Git Operations (Completed) ---"
fi

echo "🎉 Deployment process completed successfully for the $BRANCH branch!"
