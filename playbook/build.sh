#!/bin/bash

# LifeOS Playbook Build Script
# This script compiles the LaTeX playbook into a PDF

set -e  # Exit on error

echo "=========================================="
echo "LifeOS Playbook PDF Builder"
echo "=========================================="
echo ""

# Check if pdflatex is installed
if ! command -v pdflatex &> /dev/null; then
    echo "❌ Error: pdflatex is not installed"
    echo ""
    echo "Please install LaTeX distribution:"
    echo "  macOS: brew install --cask mactex"
    echo "  Ubuntu: sudo apt-get install texlive-full"
    echo "  Windows: Download MiKTeX from https://miktex.org/"
    exit 1
fi

echo "✓ pdflatex found"
echo ""

# Create output directory
mkdir -p output

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -f output/*.pdf output/*.aux output/*.log output/*.toc output/*.out output/*.lof output/*.lot

# Build the PDF (run twice for TOC and references)
echo "📝 Building PDF (first pass)..."
cd "$(dirname "$0")"
pdflatex -output-directory=output -interaction=nonstopmode main.tex > /dev/null 2>&1 || {
    echo "❌ First pass failed. Check output/main.log for errors"
    exit 1
}

echo "📝 Building PDF (second pass for TOC)..."
pdflatex -output-directory=output -interaction=nonstopmode main.tex > /dev/null 2>&1 || {
    echo "❌ Second pass failed. Check output/main.log for errors"
    exit 1
}

echo "📝 Building PDF (third pass for references)..."
pdflatex -output-directory=output -interaction=nonstopmode main.tex > /dev/null 2>&1 || {
    echo "❌ Third pass failed. Check output/main.log for errors"
    exit 1
}

# Copy final PDF to root
cp output/main.pdf LifeOS-Complete-Playbook.pdf

echo ""
echo "=========================================="
echo "✅ SUCCESS! PDF generated successfully"
echo "=========================================="
echo ""
echo "📄 Output: LifeOS-Complete-Playbook.pdf"
echo "📊 File size: $(du -h LifeOS-Complete-Playbook.pdf | cut -f1)"
echo ""
echo "To view the PDF:"
echo "  open LifeOS-Complete-Playbook.pdf"
echo ""
