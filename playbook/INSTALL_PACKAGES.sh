#!/bin/bash

# Install required LaTeX packages for LifeOS Playbook
# This script installs packages needed beyond BasicTeX

echo "=========================================="
echo "Installing LaTeX Packages for LifeOS Playbook"
echo "=========================================="
echo ""

# Check if tlmgr is available
if ! command -v tlmgr &> /dev/null; then
    echo "❌ Error: tlmgr not found"
    echo ""
    echo "Please install MacTeX or BasicTeX first:"
    echo "  brew install --cask mactex"
    echo "  or"
    echo "  brew install --cask basictex"
    exit 1
fi

echo "✓ tlmgr found"
echo ""

# Update tlmgr
echo "📦 Updating tlmgr..."
sudo tlmgr update --self

# Install required packages
echo ""
echo "📦 Installing required packages..."
echo ""

packages=(
    "titlesec"
    "tocloft"
    "listings"
    "longtable"
    "booktabs"
    "array"
    "multirow"
    "enumitem"
    "amsmath"
    "amssymb"
    "tikz"
    "pgfplots"
    "float"
    "caption"
    "subcaption"
    "appendix"
    "pdfpages"
    "setspace"
    "parskip"
    "microtype"
    "hyperref"
    "collection-fontsrecommended"
)

for package in "${packages[@]}"; do
    echo "Installing $package..."
    sudo tlmgr install "$package" 2>&1 | grep -v "already installed"
done

echo ""
echo "=========================================="
echo "✅ All packages installed successfully!"
echo "=========================================="
echo ""
echo "You can now build the PDF:"
echo "  cd playbook"
echo "  ./build.sh"
echo ""
