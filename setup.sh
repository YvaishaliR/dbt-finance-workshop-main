#!/bin/bash
# dbt Finance Workshop - Setup Script (Mac/Linux)

echo "🚀 Setting up dbt Finance Workshop..."
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8+ first."
    echo "   Download from: https://www.python.org/downloads/"
    exit 1
fi

echo "✅ Python 3 found: $(python3 --version)"
echo ""

# Create virtual environment
echo "📦 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Install dbt
echo "📥 Installing dbt-core and dbt-duckdb..."
pip install --upgrade pip
pip install dbt-core dbt-duckdb

# Create .dbt directory if it doesn't exist
echo "📁 Setting up dbt profile directory..."
mkdir -p ~/.dbt

# Copy profiles.yml if it doesn't exist
if [ ! -f ~/.dbt/profiles.yml ]; then
    echo "📋 Copying profiles.yml to ~/.dbt/"
    cp profiles.yml ~/.dbt/profiles.yml
else
    echo "⚠️  profiles.yml already exists in ~/.dbt/, skipping..."
fi

# Verify installation
echo ""
echo "🔍 Verifying installation..."
dbt --version

# Test connection
echo ""
echo "🔌 Testing dbt connection..."
dbt debug

echo ""
echo "✨ Setup complete! Next steps:"
echo ""
echo "1. Make sure virtual environment is activated:"
echo "   source venv/bin/activate"
echo ""
echo "2. Load sample data:"
echo "   dbt seed"
echo ""
echo "3. Run your first model:"
echo "   dbt run --select stg_transactions"
echo ""
echo "4. Open docs/MODULE_01.md to start learning!"
echo ""
echo "Happy learning! 🎓"
