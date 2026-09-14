import urllib.request
import os

SOUNDS = {
    "real_fire_alarm.ogg": "https://upload.wikimedia.org/wikipedia/commons/8/82/Smoke_detector_alarm.ogg",
    "real_horn.ogg": "https://upload.wikimedia.org/wikipedia/commons/e/e0/Car_horn_2.ogg",
    "real_baby_crying.ogg": "https://upload.wikimedia.org/wikipedia/commons/0/06/Baby_crying_1.ogg",
    "real_ambulance.ogg": "https://upload.wikimedia.org/wikipedia/commons/0/07/Ambulance_siren_in_Zaporizhia.ogg",
    "real_screaming.ogg": "https://upload.wikimedia.org/wikipedia/commons/2/24/Scream-man.ogg"
}

def main():
    dest_dir = os.path.dirname(__file__)
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    for filename, url in SOUNDS.items():
        filepath = os.path.join(dest_dir, filename)
        print(f"Downloading {filename} from {url}...")
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req) as response, open(filepath, 'wb') as out_file:
                out_file.write(response.read())
            print(f"Successfully downloaded {filename}")
        except Exception as e:
            print(f"Failed to download {filename}: {e}")

if __name__ == "__main__":
    main()
