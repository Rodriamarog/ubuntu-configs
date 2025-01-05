#!/bin/bash
set -e
echo "Starting GitHub SSH setup and development tools installation..."

if [ "$EUID" -eq 0 ]; then
   echo "Please do NOT run with sudo. Run as normal user."
   exit 1
fi

install_python() {
   echo "Installing Python..."
   # Add deadsnakes PPA for latest Python
   sudo add-apt-repository ppa:deadsnakes/ppa -y
   sudo apt update
   # Install latest Python (currently 3.12)
   sudo apt install -y python3.12 python3.12-venv python3.12-dev python3-pip
   # Make Python 3.12 the default python3
   sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
}

install_go() {
   echo "Installing Go..."
   # Download latest Go version
   LATEST_GO_VERSION=$(curl -s https://go.dev/VERSION?m=text)
   wget "https://go.dev/dl/${LATEST_GO_VERSION}.linux-amd64.tar.gz"
   # Remove any existing Go installation
   sudo rm -rf /usr/local/go
   # Extract Go to /usr/local
   sudo tar -C /usr/local -xzf "${LATEST_GO_VERSION}.linux-amd64.tar.gz"
   # Add Go to PATH if not already present
   if ! grep -q "/usr/local/go/bin" ~/.profile; then
       echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
   fi
   # Clean up downloaded file
   rm "${LATEST_GO_VERSION}.linux-amd64.tar.gz"
}

# Prompt for GitHub email
read -p "Enter your GitHub email: " GITHUB_EMAIL

# Check if SSH key already exists
if [ -f ~/.ssh/id_ed25519 ]; then
   echo "SSH key already exists. Skipping key generation..."
else
   # Generate SSH key
   echo "Generating new SSH key..."
   ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f ~/.ssh/id_ed25519 -N ""
fi

# Start ssh-agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard and provide instructions
sudo apt install -y xclip
xclip -sel clip < ~/.ssh/id_ed25519.pub

# Configure git with user email and name
read -p "Enter your GitHub username: " GITHUB_USERNAME
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# Set git to use SSH instead of HTTPS
git config --global url."git@github.com:".insteadOf "https://github.com/"

# Function to clone or pull repository
clone_or_pull() {
   local repo_name=$(basename "$1" .git)
   if [ -d "$repo_name" ]; then
       echo "Repository $repo_name already exists, pulling latest changes..."
       cd "$repo_name"
       git pull
       cd ..
   else
       echo "Cloning $repo_name..."
       git clone "$1"
   fi
}

# Install Python and Go
install_python
install_go

# Clone/pull specified repositories
echo "Cloning repositories in current directory: $(pwd)"
clone_or_pull "https://github.com/Rodriamarog/neurocrow.git"
clone_or_pull "https://github.com/Rodriamarog/VanTec.git"

echo "
===========================================
Your SSH key has been:
1. Generated
2. Added to the SSH agent
3. Copied to your clipboard

Your repositories have been cloned to: $(pwd)

Python and Go have been installed:
- Latest Python has been installed and set as default python3
- Latest Go has been installed in /usr/local/go
- Go has been added to your PATH

Next steps:
1. Go to GitHub.com
2. Click your profile photo > Settings
3. Click 'SSH and GPG keys' > 'New SSH key'
4. Give it a title (e.g., 'My Ubuntu Machine')
5. Paste the key from your clipboard
6. Click 'Add SSH key'

To test your connection, run:
ssh -T git@github.com

Your git is also configured with:
- Email: $GITHUB_EMAIL
- Username: $GITHUB_USERNAME
- SSH as default protocol

Note: You may need to log out and back in for Go PATH changes to take effect.
===========================================
"