import os
import time
import wave
import numpy as np
import sounddevice as sd

SAMPLE_RATE = 16000
DURATION = 1.0  # 1.0 second per training sample
DATASET_DIR = "dataset"

CLASSES = [
    "fire_alarm",
    "ambulance_siren",
    "vehicle_horn",
    "baby_crying",
    "dog_barking",
    "udaw",
    "ginna",
    "karadarayak",
    "parissamin",
    "ehata_wenna",
    "balagena",
    "background_other"
]

def record_sample(duration=DURATION, fs=SAMPLE_RATE):
    print("   🎙️ RECORDING NOW... (Speak / Play Sound!)")
    audio = sd.rec(int(duration * fs), samplerate=fs, channels=1, dtype='int16')
    sd.wait()
    print("   ✅ RECORDED!")
    return audio

def save_wav(file_path, audio_data, fs=SAMPLE_RATE):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with wave.open(file_path, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(fs)
        wf.writeframes(audio_data.tobytes())

def main():
    print("=" * 60)
    print("🎤 REAL AUDIO DATASET RECORDER (AcousticAware)")
    print("=" * 60)
    print("Use this tool to record real sounds and Sinhala spoken keywords")
    print("directly from your microphone for accurate model training.\n")

    while True:
        print("Available Sound & Keyword Classes:")
        for idx, name in enumerate(CLASSES):
            class_dir = os.path.join(DATASET_DIR, name)
            count = len(os.listdir(class_dir)) if os.path.exists(class_dir) else 0
            print(f"  [{idx + 1:2d}] {name:<20} (Existing samples: {count})")
        print("  [ 0] Exit Recorder")

        try:
            choice = input("\nSelect class number to record (or 0 to quit): ").strip()
            if not choice or choice == '0':
                break
            
            choice_idx = int(choice) - 1
            if choice_idx < 0 or choice_idx >= len(CLASSES):
                print("❌ Invalid selection, try again.\n")
                continue

            selected_class = CLASSES[choice_idx]
            class_dir = os.path.join(DATASET_DIR, selected_class)
            os.makedirs(class_dir, exist_ok=True)

            num_to_record = input(f"How many samples to record for '{selected_class}'? (default: 5): ").strip()
            num_to_record = int(num_to_record) if num_to_record.isdigit() else 5

            print(f"\n--- Recording {num_to_record} samples for '{selected_class}' ---")
            for i in range(num_to_record):
                input(f"\nPress [ENTER] when ready to record sample #{i+1} of {num_to_record}...")
                audio = record_sample(duration=DURATION)
                
                timestamp = int(time.time() * 1000)
                file_name = f"real_{selected_class}_{timestamp}_{i+1}.wav"
                file_path = os.path.join(class_dir, file_name)
                save_wav(file_path, audio)
                print(f"   💾 Saved to: {file_path}")

            print(f"\n🎉 Finished recording {num_to_record} samples for '{selected_class}'!\n")
            print("-" * 60)

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"❌ Error: {e}\n")

    print("\n✅ Recording session complete!")
    print("To retrain the neural model with your new real samples, run:")
    print("   python train_multibranch_model.py\n")

if __name__ == "__main__":
    main()
