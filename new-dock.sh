#!/bin/bash
set -e
echo "Starting system configuration..."

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Get the actual username
ACTUAL_USER=$SUDO_USER
USER_HOME=$(getent passwd $ACTUAL_USER | cut -d: -f6)

# Function declarations
check_package() {
    if dpkg -l "$1" &> /dev/null; then
        return 0 # Found
    else
        return 1 # Not found
    fi
}

check_dash_to_dock() {
    if su - $ACTUAL_USER -c "gnome-extensions list | grep -q 'dash-to-dock@micxgx.gmail.com'"; then
        return 0 # Found
    else
        return 1 # Not found
    fi
}

check_theme() {
    local theme_path="$1"
    if [ -d "$theme_path" ]; then
        return 0 # Found
    else
        return 1 # Not found
    fi
}

install_themes_and_dock() {
    echo "Installing themes and dock..."
    
    # Install required build dependencies
    apt update
    apt install -y git make gettext sassc gtk2-engines-murrine gtk2-engines-pixbuf

    # Install Dash to Dock if not present
    if ! check_dash_to_dock; then
        echo "Installing Dash to Dock..."
        cd /tmp
        rm -rf dash-to-dock
        git clone https://github.com/micheleg/dash-to-dock.git
        cd dash-to-dock
        make

        EXTENSION_PATH="$USER_HOME/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com"
        mkdir -p "$EXTENSION_PATH"
        cp *.js "$EXTENSION_PATH/"
        cp metadata.json "$EXTENSION_PATH/"
        cp stylesheet.css "$EXTENSION_PATH/"
        cp -r media "$EXTENSION_PATH/"
        
        mkdir -p "$EXTENSION_PATH/schemas"
        cp schemas/*.xml "$EXTENSION_PATH/schemas/"
        cp schemas/gschemas.compiled "$EXTENSION_PATH/schemas/"
        glib-compile-schemas "$EXTENSION_PATH/schemas/"
        
        for mo in po/*.mo; do
            lang=$(basename "$mo" .mo)
            mkdir -p "$EXTENSION_PATH/locale/$lang/LC_MESSAGES"
            cp "$mo" "$EXTENSION_PATH/locale/$lang/LC_MESSAGES/dashtodock.mo"
        done
        
        chown -R $ACTUAL_USER:$ACTUAL_USER "$USER_HOME/.local"
    else
        echo "Dash to Dock already installed, skipping installation..."
    fi

    # Install Mojave icons if not present
    if ! check_theme "/usr/share/icons/McMojave-circle"; then
        echo "Installing Mojave icons..."
        cd /tmp
        rm -rf McMojave-circle
        git clone https://github.com/vinceliuice/McMojave-circle.git
        cd McMojave-circle
        ./install.sh
    else
        echo "Mojave icons already installed, skipping..."
    fi

    # Install Orchis GTK theme if not present
    if ! check_theme "/usr/share/themes/Orchis-Dark"; then
        echo "Installing Orchis GTK theme..."
        cd /tmp
        rm -rf Orchis-theme
        git clone https://github.com/vinceliuice/Orchis-theme.git
        cd Orchis-theme
        ./install.sh
    else
        echo "Orchis theme already installed, skipping..."
    fi
}

configure_appearance() {
    echo "Configuring appearance settings..."
    
    # Configure Dash to Dock
    su - $ACTUAL_USER -c "gnome-extensions disable ubuntu-dock@ubuntu.com" || true
    su - $ACTUAL_USER -c "gnome-extensions enable dash-to-dock@micxgx.gmail.com"

    # Configure dock settings
    su - $ACTUAL_USER -c "
    gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize';
    gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED';
    gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.0;
    gsettings set org.gnome.shell.extensions.dash-to-dock custom-background-color false;
    "

    # Apply themes and dark mode
    su - $ACTUAL_USER -c "
    gsettings set org.gnome.desktop.interface gtk-theme 'Orchis-Dark';
    gsettings set org.gnome.desktop.interface icon-theme 'McMojave-circle-dark';
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark';
    gsettings set org.gnome.desktop.interface enable-animations true;
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme true;
    gsettings set org.gnome.shell.extensions.user-theme name 'Orchis-Dark';
    "
}

install_development_tools() {
    echo "Installing development tools..."
    
    # Install VSCode if not present
    if ! check_package "code"; then
        echo "Installing Visual Studio Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
        install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
        apt update
        apt install -y code
    else
        echo "VSCode already installed, skipping..."
    fi

    # Install Sublime Text if not present
    if ! check_package "sublime-text"; then
        echo "Installing Sublime Text..."
        wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor > /tmp/sublimehq-pub.gpg
        install -D -o root -g root -m 644 /tmp/sublimehq-pub.gpg /etc/apt/keyrings/sublimehq-pub.gpg
        echo "deb [signed-by=/etc/apt/keyrings/sublimehq-pub.gpg] https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list
        apt update
        apt install -y sublime-text
    else
        echo "Sublime Text already installed, skipping..."
    fi
}

configure_sublime() {
    echo "Configuring Sublime Text..."
    
    # Create Sublime Text config directory
    SUBLIME_CONFIG_DIR="$USER_HOME/.config/sublime-text/Packages/User"
    mkdir -p "$SUBLIME_CONFIG_DIR"

    # Create preferences file
    cat > "$SUBLIME_CONFIG_DIR/Preferences.sublime-settings" << EOF
{
    "font_size": 16,
    "font_face": "Jetbrains Mono",
    "save_on_focus_lost": true,
    "highlight_line": true,
    "caret_style": "phase",
    "line_padding_bottom": 10,
    "line_padding_top": 10,
    "theme": "Adaptive.sublime-theme"
}
EOF

    # Install Aura theme
    AURA_TEMP_DIR="$USER_HOME/Aura Theme Color Scheme"
    SUBLIME_PACKAGES_DIR="$USER_HOME/.config/sublime-text/Packages"
    mkdir -p "$AURA_TEMP_DIR"
    mkdir -p "$SUBLIME_PACKAGES_DIR"

    wget -O "$AURA_TEMP_DIR/aura-theme.tmTheme" https://raw.githubusercontent.com/daltonmenezes/aura-theme/main/packages/sublime-text/aura-theme.tmTheme
    mv "$AURA_TEMP_DIR" "$SUBLIME_PACKAGES_DIR/"

    # Update preferences with theme
    cat > "$SUBLIME_CONFIG_DIR/Preferences.sublime-settings" << EOF
{
    "font_size": 16,
    "font_face": "Jetbrains Mono",
    "save_on_focus_lost": true,
    "highlight_line": true,
    "caret_style": "phase",
    "line_padding_bottom": 10,
    "line_padding_top": 10,
    "theme": "Adaptive.sublime-theme",
    "color_scheme": "Packages/Aura Theme Color Scheme/aura-theme.tmTheme"
}
EOF

    # Fix permissions
    chown -R $ACTUAL_USER:$ACTUAL_USER "$USER_HOME/.config/sublime-text"
    chown -R $ACTUAL_USER:$ACTUAL_USER "$SUBLIME_PACKAGES_DIR/Aura Theme Color Scheme"
}

# Main execution
install_themes_and_dock
configure_appearance
install_development_tools
configure_sublime

echo "All installations and configurations complete! Please log out and back in for all changes to take effect."