#!/bin/bash


# Licensed under MIT
# https://theindiandev.in
# https://github.com/the-indian-dev/simple-minifier
#
# I recommend doing compressions manually for static assets like
# images and fonts using standard tools like imagemagick and 
# woff2_compress. Anyways the following codebase is vibe-coded
# because I needed something lighter for deploying simple static websites
# on cloudflare pages. You are recommended to use standard tools like
# webpack for heavier websites. It outputs the final compiled result to
# dist/ directory. You can see the total savings at end too.
#
# ==============================================================================
#  Features:
#  - Recursive Directory Scanning
#  - Strict HTML Minification (Short Doctype, Type removal, Whitespace collapse)
#  - Strict CSS Minification (Hex shortening, Zero stripping, Space removal)
#  - Asset Copying
# ==============================================================================

# --- CONFIGURATION ---
SOURCE_DIR="."
BUILD_DIR="./dist"
IGNORE_DIRS=(".git" "node_modules" "venv" "$BUILD_DIR")

# --- COLORS ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- TIMING & STATS ---
START_TIME=$SECONDS
COUNT_HTML=0
COUNT_CSS=0
COUNT_COPY=0

# --- PREPARATION ---
echo -e "${BOLD}${BLUE}Starting Minification Engine...${NC}"

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# --- OPTIMIZATION FUNCTIONS (PERL) ---

# CSS MINIFIER
# 1. Remove Comments
# 2. Collapse whitespace (newlines/tabs -> space)
# 3. Remove space around safe delimiters { } : ; , >
# 4. Hex Shortening (#aabbcc -> #abc)
# 5. Zero Unit Optimization (0px -> 0)
# 6. Remove trailing semicolon (SAFE: replaces ;} with })
minify_css_safe() {
    perl -0777 -pe '
    s|/\*.*?\*/||gs;                            # Remove comments
    s/\s+/ /gs;                                 # Collapse whitespace
    s/\s*([\{\};:,>])\s*/$1/g;                  # Remove space around delimiters
    s/#([0-9a-fA-F])\1([0-9a-fA-F])\2([0-9a-fA-F])\3/#$1$2$3/g; # Hex Shortener
    s/(:| )0(px|em|ex|cm|mm|in|pt|pc|%)/$1.0/g; # Zero Unit Stripper
    s/([^0-9])0\.(\d+)/$1.$2/g;                 # .5px Optimization
    s/;}/}/g;                                   # Remove trailing semi (SAFE)
    '
}

# HTML MINIFIER (STRUCTURE FOCUSED)
# 1. Remove Comments
# 2. Short Doctype
# 3. Collapse whitespace to single space
# 4. Remove space between tags ONLY if the next tag is a real tag (starts with letter or /)
#    This preserves content like "<p> > < </p>" while shrinking "<head> <body>"
minify_html_safe() {
    perl -0777 -pe '
    s/<!--.*?-->//gs;                                  # Remove comments
    s/<!DOCTYPE[^>]+>/<!doctype html>/i;               # Short doctype
    s/ type=["\047]text\/(javascript|css)["\047]//gi;  # Remove script/style types
    s/\s+/ /g;                                         # Collapse whitespace
    s/>\s+<([a-zA-Z\/])/><\1/g;                        # Safe Tag Merging
    '
}

# --- UTILS ---
human_readable_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then echo "${size}B"; 
    elif [ "$size" -lt 1048576 ]; then echo "$(( (size * 100) / 1024 ))" | awk '{printf "%.2fKB", $1/100}'; 
    else echo "$(( (size * 100) / 1048576 ))" | awk '{printf "%.2fMB", $1/100}'; fi
}

# --- MAIN LOOP ---

# Construct Find Ignore Flags
FIND_IGNORE=""
for dir in "${IGNORE_DIRS[@]}"; do
    clean_dir=${dir#./}
    FIND_IGNORE="$FIND_IGNORE -not -path \"*/$clean_dir*\""
done

echo -e "Scanning: ${CYAN}$SOURCE_DIR${NC}\n"

# Process files
eval "find \"$SOURCE_DIR\" -type f $FIND_IGNORE -not -name \"$(basename "$0")\"" | while read -r FILE; do
    
    REL_PATH="${FILE#./}"
    DEST_PATH="$BUILD_DIR/$REL_PATH"
    DEST_DIR=$(dirname "$DEST_PATH")
    mkdir -p "$DEST_DIR"
    
    EXT="${FILE##*.}"
    ORIG_SIZE=$(wc -c < "$FILE")
    
    case "$EXT" in
        html|htm)
            cat "$FILE" | minify_html_safe > "$DEST_PATH"
            NEW_SIZE=$(wc -c < "$DEST_PATH")
            
            # Calculate Savings
            if [ "$ORIG_SIZE" -gt 0 ]; then PCT=$(( 100 - (NEW_SIZE * 100 / ORIG_SIZE) )); else PCT=0; fi
            [ "$PCT" -lt 0 ] && PCT=0
            
            printf "${GREEN}[HTML]${NC} %-4s saved : %s\n" "${PCT}%" "$REL_PATH"
            echo "html" >> .stats_counter
            ;;
            
        css)
            cat "$FILE" | minify_css_safe > "$DEST_PATH"
            NEW_SIZE=$(wc -c < "$DEST_PATH")
            
            if [ "$ORIG_SIZE" -gt 0 ]; then PCT=$(( 100 - (NEW_SIZE * 100 / ORIG_SIZE) )); else PCT=0; fi
            [ "$PCT" -lt 0 ] && PCT=0

            printf "${CYAN}[CSS ]${NC} %-4s saved : %s\n" "${PCT}%" "$REL_PATH"
            echo "css" >> .stats_counter
            ;;
            
        *)
            cp "$FILE" "$DEST_PATH"
            echo "copy" >> .stats_counter
            printf "${BLUE}[COPY]${NC}             : %s\n" "$REL_PATH"
            ;;
    esac
done

# --- FINAL STATS ---

# Calculate final directory sizes
SIZE_SRC=$(du -sb . --exclude="$BUILD_DIR" --exclude=".git" --exclude="node_modules" 2>/dev/null | awk '{print $1}')
SIZE_DIST=$(du -sb "$BUILD_DIR" 2>/dev/null | awk '{print $1}')

# Handle case where du might fail
[ -z "$SIZE_SRC" ] && SIZE_SRC=0
[ -z "$SIZE_DIST" ] && SIZE_DIST=0

SAVED_BYTES=$((SIZE_SRC - SIZE_DIST))
if [ "$SIZE_SRC" -gt 0 ]; then SAVED_PCT=$(( (SAVED_BYTES * 100) / SIZE_SRC )); else SAVED_PCT=0; fi

# Count files
if [ -f .stats_counter ]; then
    COUNT_HTML=$(grep -c "html" .stats_counter)
    COUNT_CSS=$(grep -c "css" .stats_counter)
    COUNT_COPY=$(grep -c "copy" .stats_counter)
    rm .stats_counter
fi

ELAPSED=$((SECONDS - START_TIME))

echo ""
echo -e "${BOLD}${BLUE}==============================================${NC}"
echo -e "${BOLD}               BUILD SUMMARY                  ${NC}"
echo -e "${BOLD}${BLUE}==============================================${NC}"
echo -e " ${BOLD}Total Time:${NC}     ${GREEN}${ELAPSED} seconds${NC}"
echo -e " ${BOLD}Processed:${NC}      HTML: ${GREEN}${COUNT_HTML}${NC} | CSS: ${CYAN}${COUNT_CSS}${NC} | Assets: ${YELLOW}${COUNT_COPY}${NC}"
echo -e " ${BOLD}Source Size:${NC}    $(human_readable_size $SIZE_SRC)"
echo -e " ${BOLD}Build Size:${NC}     $(human_readable_size $SIZE_DIST)"
echo -e " ${BOLD}Total Saved:${NC}    ${RED}$(human_readable_size $SAVED_BYTES) ($SAVED_PCT%)${NC}"
echo -e "${BOLD}${BLUE}==============================================${NC}"
