#!/bin/bash

# ========================================
# Copyright Header Injection Script
# ========================================
# Adds proprietary copyright headers to source files
# Copyright (c) 2026. All Rights Reserved.
# ========================================

set -e

COMPANY_NAME="[Your Company Name]"
YEAR="2026"

echo "🔒 Adding Copyright Headers to Source Files..."
echo ""

# ========================================
# SQL Files
# ========================================
echo "📝 Processing SQL files..."

SQL_HEADER="-- ========================================
-- Clinic Management Multi-Agent System
-- Copyright (c) $YEAR $COMPANY_NAME
-- All Rights Reserved - Proprietary License
-- ========================================
-- Unauthorized copying or distribution prohibited.
-- Licensed use only. See LICENSE file.
-- ========================================"

sql_count=0
for file in $(find scripts/migrations -name "*.sql" 2>/dev/null); do
    # Check if header already exists
    if ! grep -q "Copyright (c) $YEAR" "$file"; then
        # Create temp file with header + original content
        echo "$SQL_HEADER" > "$file.tmp"
        echo "" >> "$file.tmp"
        cat "$file" >> "$file.tmp"
        mv "$file.tmp" "$file"
        echo "   ✅ $file"
        sql_count=$((sql_count + 1))
    else
        echo "   ⏭️  $file (already has header)"
    fi
done

echo "   📊 $sql_count SQL file(s) updated"
echo ""

# ========================================
# JSON Workflow Files
# ========================================
echo "📝 Processing JSON workflow files..."

json_count=0
for file in $(find workflows -name "*.json" 2>/dev/null); do
    # Check if copyright exists
    if ! grep -q "\"_copyright\"" "$file"; then
        # Read JSON
        content=$(cat "$file")
        
        # Add copyright field at the beginning (after opening brace)
        # This is a simple approach - for complex JSON, use jq
        echo "$content" | sed '1 a\
  "_copyright": "Copyright (c) '"$YEAR"' '"$COMPANY_NAME"'. All Rights Reserved.",\
  "_license": "Proprietary - Licensed Use Only. See LICENSE file.",\
  "_warning": "Unauthorized copying, modification, or distribution is strictly prohibited.",
' > "$file.tmp"
        
        mv "$file.tmp" "$file"
        echo "   ✅ $file"
        json_count=$((json_count + 1))
    else
        echo "   ⏭️  $file (already has copyright)"
    fi
done

echo "   📊 $json_count JSON file(s) updated"
echo ""

# ========================================
# Shell Scripts
# ========================================
echo "📝 Processing shell scripts..."

SHELL_HEADER="# ========================================
# Clinic Management Multi-Agent System
# Copyright (c) $YEAR $COMPANY_NAME
# All Rights Reserved - Proprietary License
# ========================================
# Unauthorized copying or distribution prohibited.
# Licensed use only. See LICENSE file.
# ========================================"

shell_count=0
for file in $(find scripts -name "*.sh" 2>/dev/null); do
    # Skip this script itself
    if [ "$file" = "$0" ]; then
        continue
    fi
    
    # Check if header already exists
    if ! grep -q "Copyright (c) $YEAR" "$file"; then
        # Save shebang line
        shebang=$(head -n 1 "$file")
        
        # Create new file: shebang + header + rest of content
        echo "$shebang" > "$file.tmp"
        echo "" >> "$file.tmp"
        echo "$SHELL_HEADER" >> "$file.tmp"
        echo "" >> "$file.tmp"
        tail -n +2 "$file" >> "$file.tmp"
        
        mv "$file.tmp" "$file"
        chmod +x "$file"
        echo "   ✅ $file"
        shell_count=$((shell_count + 1))
    else
        echo "   ⏭️  $file (already has header)"
    fi
done

echo "   📊 $shell_count shell script(s) updated"
echo ""

# ========================================
# Markdown Documentation Files
# ========================================
echo "📝 Processing documentation files..."

MD_HEADER="> **Proprietary Documentation**  
> Copyright © $YEAR $COMPANY_NAME. All Rights Reserved.  
> This document is confidential and intended for authorized clients only.

---
"

md_count=0
for file in $(find docs -name "*.md" 2>/dev/null); do
    # Check if header already exists
    if ! grep -q "Proprietary Documentation" "$file"; then
        # Create temp file with header + original content
        echo -e "$MD_HEADER" > "$file.tmp"
        cat "$file" >> "$file.tmp"
        mv "$file.tmp" "$file"
        echo "   ✅ $file"
        md_count=$((md_count + 1))
    else
        echo "   ⏭️  $file (already has header)"
    fi
done

echo "   📊 $md_count documentation file(s) updated"
echo ""

# ========================================
# Summary
# ========================================
echo "=========================================="
echo "✅ COPYRIGHT HEADERS ADDED"
echo "=========================================="
echo ""
echo "📊 Summary:"
echo "   - SQL files: $sql_count updated"
echo "   - JSON workflows: $json_count updated"
echo "   - Shell scripts: $shell_count updated"
echo "   - Documentation: $md_count updated"
echo ""
total=$((sql_count + json_count + shell_count + md_count))
echo "   Total: $total files updated"
echo ""
echo "🔒 All source files now include copyright notices."
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Review changes with: git diff"
echo "   - Commit changes: git add -A && git commit -m 'Add copyright headers'"
echo "   - Test workflows in n8n to ensure JSON is valid"
echo ""

