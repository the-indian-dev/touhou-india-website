#!/bin/bash

# --- Configuration ---
SOURCE_DIR="gallery"
PROD_DIR="gallery-prod"
HTML_FILE="gallery.html"

SECONDS=0

# --- Pre-flight Checks ---
# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory '$SOURCE_DIR/' not found."
  echo "Please create it and add your images and text files."
  exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed. Please install it to continue."
    exit 1
fi

echo "Starting gallery generation..."

# --- 1. Cleanup and Setup ---
# Remove old generated files and directory to ensure a clean build
rm -f "$HTML_FILE"
rm -rf "$PROD_DIR"
mkdir "$PROD_DIR"

echo "Created clean production directory: $PROD_DIR/"

# --- 2. Generate the HTML Header ---
# This uses a "here document" (<<EOF) to write a block of text to the HTML file.
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="en-IN">
<head>
    <!-- Charset & Viewport -->
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <!-- Primary Meta Tags -->
    <title>Gallery | Touhou Discord Server India</title>
    <meta name="description" content="A gallery of community fanart and creations from the Touhou India Discord server.">

    <!-- Stylesheets -->
    <link rel="stylesheet" href="styles.css">
    <link rel="stylesheet" href="gallery-styles.css">

    <!-- Favicon -->
    <link rel="icon" href="/favicon.ico" type="image/x-icon">
</head>
<body>
    <main>
        <div class="content-wrapper-gallery">
            <header>
                <h1 class="title">
                    <span class="title-gif">
                        <img src="img/india-flag.webp" alt="The flag of India waving">
                    </span>
                    Community Gallery
                    <span class="title-gif">
                        <img src="img/remiliawalk.webp"
                            alt="A blue haired vampired walking with her wings spread. She is Remilia Scarlet from Touhou Project">
                    </span>
                </h1>
                <nav class="main-nav">
                    <b><a href="https://discord.gg/WUtvqWzggk" target="_blank">Join our server </a></b>
                    &bull;
                    <b><a href="index.html">Home</a></b>
                </nav>
            </header>
            <p>Here are some of the fanarts drawn by our community members. The images are copyrights of the 
            respective owner if you want repost/reuse them please contact their respective owners. We have posted it here with their 
            permission. <a href="https://github.com/the-indian-dev/touhou-india-website/tree/master/gallery" target="_blank">Visit our Github repository</a> for uncompressed 
            version of the fanarts.</p>
            <section class="gallery-container">
EOF

# --- 3. Process Images and Generate HTML for each item ---
# Loop over all jpg, jpeg, and png files in the source directory
for image_path in "$SOURCE_DIR"/*.{jpg,jpeg,png}; do
    # Check if a file matching the pattern was found
    [ -f "$image_path" ] || continue

    # Extract filename without extension (e.g., "mima.png" -> "mima")
    filename=$(basename -- "$image_path")
    base_name="${filename%.*}"

    # Define paths for the text file and the output webp image
    text_file="$SOURCE_DIR/$base_name.txt"
    webp_output="$PROD_DIR/$base_name.webp"

    echo "Processing: $filename"

    # --- Image Conversion ---
    # Convert the image to .webp format and place it in the prod directory
    # compress and resize large images
    convert "$image_path" -quality 60 -resize 900x900\> "$webp_output"

    # --- Read Description Text ---
    # Check if the corresponding text file exists
    if [ -f "$text_file" ]; then
        # Read the file content, escape HTML special characters, and replace newlines with <br>
        description=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$text_file" | awk 'NF > 0{printf "%s<br>", $0}' | sed 's/<br>$//')
        # Use first line for a cleaner alt text
        alt_text=$(head -n 1 "$text_file")
        alt_text=${alt_text//\"/}
        echo $alt_text
    else
        description="No description provided."
        alt_text="Gallery image $filename"
    fi

    # --- Generate HTML fragment for this image and append it to the main HTML file ---
    cat <<EOF >> "$HTML_FILE"
                <div class="gallery-item">
                    <a href="$webp_output" target="_blank" title="Click to view full image">
                        <img src="$webp_output" alt="$alt_text" loading="lazy">
                    </a>
                    <p class="caption">$description</p>
                </div>
EOF

done

# --- 4. Generate the HTML Footer ---
cat <<EOF >> "$HTML_FILE"
            </section>
        </div>
    </main>
    <footer>
        <p class="notice" role="note">Please note that this server is not associated with Team Shanghai Alice; it's an
            unofficial fan-made Discord server!</p>
        <p>This website is open source and licensed under MIT. <a href="https://github.com/the-indian-dev/touhou-india-website">Fork me on Github!</a></p>
    </footer>
</body>
</html>
EOF

duration=$SECONDS

echo "-----------------------------------"
echo "Website Generation complete!"
echo "Compilation complete in $((duration / 60)) minutes and $((duration % 60)) seconds."
echo "Generated files: $HTML_FILE and $PROD_DIR/"
