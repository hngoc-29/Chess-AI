import urllib.request
import os

def download_file(url, dest_path):
    print(f"Downloading {url} to {dest_path}...")
    try:
        urllib.request.urlretrieve(url, dest_path)
        print("Success!")
    except Exception as e:
        print(f"Failed: {e}")

# Create directories if they don't exist
os.makedirs('game/assets/sounds', exist_ok=True)
os.makedirs('game/assets/fonts', exist_ok=True)

# Download a free background music track (Creative Commons)
download_file(
    'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0a13f69d2.mp3?filename=ambient-piano-amp-strings-10711.mp3',
    'game/assets/sounds/background_music.mp3'
)

# Download a font (Roboto)
download_file(
    'https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Regular.ttf',
    'game/assets/fonts/Roboto-Regular.ttf'
)
download_file(
    'https://github.com/google/fonts/raw/main/apache/roboto/Roboto-Bold.ttf',
    'game/assets/fonts/Roboto-Bold.ttf'
)
