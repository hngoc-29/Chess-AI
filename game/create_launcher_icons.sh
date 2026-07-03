#!/bin/bash
set -e

echo "🎯 Creating Android launcher icons for King's Gambit AI..."

# Define the base directory
BASE_DIR="android/app/src/main/res"

# Create icon directories if they don't exist
mkdir -p "$BASE_DIR/mipmap-mdpi"
mkdir -p "$BASE_DIR/mipmap-hdpi"
mkdir -p "$BASE_DIR/mipmap-xhdpi"
mkdir -p "$BASE_DIR/mipmap-xxhdpi"
mkdir -p "$BASE_DIR/mipmap-xxxhdpi"

# Check for Python PIL/Pillow
if python3 -c "from PIL import Image" 2>/dev/null; then
    echo "✓ PIL available, generating quality icons..."
    python3 generate_icons.py
    exit 0
fi

# Fallback: Use ImageMagick if available
if command -v convert &> /dev/null; then
    echo "✓ ImageMagick available, generating icons..."

    # Chess-themed color scheme
    BG_COLOR="#22313F"  # Dark blue-gray
    FG_COLOR="#2ECC71"  # Green

    for size in 48:mdpi 72:hdpi 96:xhdpi 144:xxhdpi 192:xxxhdpi; do
        IFS=':' read -r pixels density <<< "$size"
        output="$BASE_DIR/mipmap-$density/ic_launcher.png"

        # Create a simple chess-themed icon with a border
        convert -size ${pixels}x${pixels} xc:"$BG_COLOR" \
                -fill "$FG_COLOR" \
                -draw "rectangle $((pixels/4)),$((pixels/4)) $((pixels*3/4)),$((pixels*3/4))" \
                -stroke white -strokewidth $((pixels/48 > 0 ? pixels/48 : 1)) \
                -draw "rectangle $((pixels/4)),$((pixels/4)) $((pixels*3/4)),$((pixels*3/4))" \
                "$output"

        echo "  ✓ Created $density (${pixels}x${pixels})"
    done

    echo "✅ All icons created with ImageMagick!"
    exit 0
fi

# Last resort: Create minimal valid PNG files using base64
echo "⚠️  Using minimal fallback icons (no PIL or ImageMagick found)"

# Base64-encoded minimal PNG data for different sizes
# These are simple solid color PNGs - not pretty but valid

# 48x48 PNG (mdpi) - minimal solid color
ICON_48="iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEgAACxIB0t1+/AAAABx0RVh0U29mdHdhcmUAQWRvYmUgRmlyZXdvcmtzIENTNui8sowAAAAWdEVYdENyZWF0aW9uIFRpbWUAMDcvMDIvMjYxO/JuAAAAE0lEQVRoge3OMQEAAAjDMMC/52EC0E5gAAAAAADAJzyUADEIGvOEAAAAAElFTkSuQmCC"

# 72x72 PNG (hdpi)
ICON_72="iVBORw0KGgoAAAANSUhEUgAAAEgAAABICAYAAABV7bNHAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEgAACxIB0t1+/AAAABx0RVh0U29mdHdhcmUAQWRvYmUgRmlyZXdvcmtzIENTNui8sowAAAAWdEVYdENyZWF0aW9uIFRpbWUAMDcvMDIvMjYxO/JuAAAAE0lEQVR4nO3OMQEAAAjDMOC/52EC0E5gAAAAAADAJzzYADEIGvOEAAAAAElFTkSuQmCC"

# 96x96 PNG (xhdpi)
ICON_96="iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEgAACxIB0t1+/AAAABx0RVh0U29mdHdhcmUAQWRvYmUgRmlyZXdvcmtzIENTNui8sowAAAAWdEVYdENyZWF0aW9uIFRpbWUAMDcvMDIvMjYxO/JuAAAAE0lEQVR4nO3OMQEAAAjDMOC/52EC0E5gAAAAAADAJzz8ADEIGvOEAAAAAElFTkSuQmCC"

# 144x144 PNG (xxhdpi)
ICON_144="iVBORw0KGgoAAAANSUhEUgAAAJAAAACQCAYAAADnRuK4AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEgAACxIB0t1+/AAAABx0RVh0U29mdHdhcmUAQWRvYmUgRmlyZXdvcmtzIENTNui8sowAAAAWdEVYdENyZWF0aW9uIFRpbWUAMDcvMDIvMjYxO/JuAAAAE0lEQVR4nO3OMQEAAAjDMOC/52EC0E5gAAAAAADAJzw0ATEIGvOEAAAAAElFTkSuQmCC"

# 192x192 PNG (xxxhdpi)
ICON_192="iVBORw0KGgoAAAANSUhEUgAAAMAAAADACAYAAABS3GwHAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEgAACxIB0t1+/AAAABx0RVh0U29mdHdhcmUAQWRvYmUgRmlyZXdvcmtzIENTNui8sowAAAAWdEVYdENyZWF0aW9uIFRpbWUAMDcvMDIvMjYxO/JuAAAAE0lEQVR4nO3OMQEAAAjDMOC/52EC0E5gAAAAAADAJzxkATEIGvOEAAAAAElFTkSuQmCC"

# Decode and write icons
echo -n "$ICON_48" | base64 -d > "$BASE_DIR/mipmap-mdpi/ic_launcher.png"
echo "  ✓ Created mdpi (48x48)"

echo -n "$ICON_72" | base64 -d > "$BASE_DIR/mipmap-hdpi/ic_launcher.png"
echo "  ✓ Created hdpi (72x72)"

echo -n "$ICON_96" | base64 -d > "$BASE_DIR/mipmap-xhdpi/ic_launcher.png"
echo "  ✓ Created xhdpi (96x96)"

echo -n "$ICON_144" | base64 -d > "$BASE_DIR/mipmap-xxhdpi/ic_launcher.png"
echo "  ✓ Created xxhdpi (144x144)"

echo -n "$ICON_192" | base64 -d > "$BASE_DIR/mipmap-xxxhdpi/ic_launcher.png"
echo "  ✓ Created xxxhdpi (192x192)"

echo ""
echo "✅ All launcher icons created successfully!"
echo "ℹ️  Note: These are basic placeholder icons. For production, use proper chess-themed icons."
