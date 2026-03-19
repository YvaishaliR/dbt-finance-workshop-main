@echo off
REM dbt Finance Workshop - Setup Script (Windows)

echo.
echo 🚀 Setting up dbt Finance Workshop...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python 3 is not installed. Please install Python 3.8+ first.
    echo    Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo ✅ Python found: %PYTHON_VERSION%
echo.

REM Create virtual environment
echo 📦 Creating virtual environment...
python -m venv venv

REM Activate virtual environment
echo 🔌 Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dbt
echo 📥 Installing dbt-core and dbt-duckdb...
python -m pip install --upgrade pip
pip install dbt-core dbt-duckdb

REM Create .dbt directory if it doesn't exist
echo 📁 Setting up dbt profile directory...
if not exist "%USERPROFILE%\.dbt" mkdir "%USERPROFILE%\.dbt"

REM Copy profiles.yml if it doesn't exist
if not exist "%USERPROFILE%\.dbt\profiles.yml" (
    echo 📋 Copying profiles.yml to %USERPROFILE%\.dbt\
    copy profiles.yml "%USERPROFILE%\.dbt\profiles.yml"
) else (
    echo ⚠️  profiles.yml already exists, skipping...
)

REM Verify installation
echo.
echo 🔍 Verifying installation...
dbt --version

REM Test connection
echo.
echo 🔌 Testing dbt connection...
dbt debug

echo.
echo ✨ Setup complete! Next steps:
echo.
echo 1. Make sure virtual environment is activated:
echo    venv\Scripts\activate
echo.
echo 2. Load sample data:
echo    dbt seed
echo.
echo 3. Run your first model:
echo    dbt run --select stg_transactions
echo.
echo 4. Open docs\MODULE_01.md to start learning!
echo.
echo Happy learning! 🎓
echo.
pause
