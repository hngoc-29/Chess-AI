#!/usr/bin/env python3
"""Generate Android launcher icons for Chess AI app."""

import os
import sys

def create_simple_png(width, height, color_bg, color_fg=None):
    """Create a simple PNG image without PIL - using minimal PNG structure."""
    import struct
    import zlib

    # Create RGBA image data
    img_data = bytearray()

    # Simple chess board pattern or solid color
    for y in range(height):
        img_data.append(0)  # Filter type
        for x in range(width):
            if color_fg and (x + y) % 2 == 0:
                # Checkerboard pattern
                r, g, b, a = color_fg
            else:
                r, g, b, a = color_bg
            img_data.extend([r, g, b, a])

    # Compress image data
    compressed = zlib.compress(bytes(img_data), 9)

    # PNG signature
    png = b'\x89PNG\r\n\x1a\n'

    # IHDR chunk
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png += struct.pack('>I', 13)  # Length
    png += b'IHDR' + ihdr
    png += struct.pack('>I', zlib.crc32(b'IHDR' + ihdr) & 0xffffffff)

    # IDAT chunk
    png += struct.pack('>I', len(compressed))
    png += b'IDAT' + compressed
    png += struct.pack('>I', zlib.crc32(b'IDAT' + compressed) & 0xffffffff)

    # IEND chunk
    png += struct.pack('>I', 0)
    png += b'IEND'
    png += struct.pack('>I', zlib.crc32(b'IEND') & 0xffffffff)

    return png

def generate_launcher_icons():
    """Generate launcher icons for all Android densities."""

    # Color scheme: Dark blue/green chess board
    bg_color = (34, 49, 63, 255)   # Dark blue-gray
    fg_color = (46, 204, 113, 255) # Green accent

    icons = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    base_path = './android/app/src/main/res'

    print("Generating Android launcher icons...")

    for density, size in icons.items():
        dir_path = os.path.join(base_path, density)

        # Create directory if it doesn't exist
        os.makedirs(dir_path, exist_ok=True)

        # Generate icon
        icon_path = os.path.join(dir_path, 'ic_launcher.png')

        try:
            # Try with PIL if available
            from PIL import Image, ImageDraw

            img = Image.new('RGBA', (size, size), bg_color)
            draw = ImageDraw.Draw(img)

            # Draw a simple chess knight silhouette or chess board pattern
            # For now, draw a simple centered square to represent a piece
            margin = size // 4
            draw.rectangle(
                [margin, margin, size - margin, size - margin],
                fill=fg_color,
                outline=(255, 255, 255, 255),
                width=max(1, size // 48)
            )

            img.save(icon_path, 'PNG')
            print(f"✓ Created {density}/ic_launcher.png ({size}x{size})")

        except ImportError:
            # Fallback: create with basic PNG structure
            png_data = create_simple_png(size, size, bg_color, fg_color)

            with open(icon_path, 'wb') as f:
                f.write(png_data)

            print(f"✓ Created {density}/ic_launcher.png ({size}x{size}) [basic]")

    print("\n✓ All launcher icons generated successfully!")
    return True

if __name__ == '__main__':
    try:
        os.chdir('/home/hn/Code/Python/ChessAI/game')
        success = generate_launcher_icons()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
