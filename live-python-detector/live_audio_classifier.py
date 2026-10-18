import os
import sys
import time
import numpy as np
import librosa
import sounddevice as sd
import tensorflow as tf

# Suppress TensorFlow logging warnings
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
tf.get_logger().setLevel('ERROR')

# Configuration (matching train_kws.py)
SAMPLE_RATE = 16000
DURATION = 1.0  # 1.0 second sliding window
N_MFCC = 40
HOP_LENGTH = 512
N_FFT = 1024
TARGET_FRAMES = 32

CLASSES = [
    "fire_alarm",
    "vehicle_horn",
    "baby_crying",
    "screaming",
    "ambulance",
    "udaw",
    "karadarayak",
    "ehaata_wenna",
    "balaagena",
    "ginnak",
    "beeraganna",
    "background_noise"
]

# Translation mapping for Sinhala emergency terms
SINHALA_MAP = {
    "udaw": "උදව් (Help / Distress)",
    "karadarayak": "කරදරයක් (Emergency / Trouble)",
    "ehaata_wenna": "එහාට වෙන්න (Move Aside / Clear Way)",
    "balaagena": "බලාගෙන (Watch Out / Hazard)",
    "ginnak": "ගින්නක් (Fire / Flame)",
    "beeraganna": "බේරාගන්න (Rescue / Save Me)"
}

PRIORITY_COLORS = {
    "fire_alarm": "\033[91;1m🚨 HIGH PRIORITY: FIRE ALARM DETECTED!\033[0m",
    "screaming": "\033[91;1m🚨 HIGH PRIORITY: VOCAL DISTRESS / SCREAMING!\033[0m",
    "ambulance": "\033[91;1m🚨 HIGH PRIORITY: EMERGENCY SIREN (AMBULANCE)!\033[0m",
    "udaw": "\033[91;1m🚨 HIGH PRIORITY: SINHALA 'HELP' VOCALIZATION!\033[0m",
    "ginnak": "\033[91;1m🚨 HIGH PRIORITY: SINHALA 'FIRE' VOCALIZATION!\033[0m",
    "beeraganna": "\033[91;1m🚨 HIGH PRIORITY: SINHALA 'RESCUE' VOCALIZATION!\033[0m",
    "karadarayak": "\033[91;1m🚨 HIGH PRIORITY: SINHALA 'EMERGENCY' VOCALIZATION!\033[0m",
    "vehicle_horn": "\033[93;1m⚠️ MEDIUM PRIORITY: VEHICLE HORN DETECTED!\033[0m",
    "baby_crying": "\033[93;1m⚠️ MEDIUM PRIORITY: BABY CRYING DETECTED!\033[0m",
    "balaagena": "\033[93;1m⚠️ MEDIUM PRIORITY: SINHALA 'WATCH OUT' VOCALIZATION!\033[0m",
    "ehaata_wenna": "\033[93;1m⚠️ MEDIUM PRIORITY: SINHALA 'MOVE ASIDE' VOCALIZATION!\033[0m",
}

# Global ring buffer for audio data
audio_buffer = np.zeros(int(SAMPLE_RATE * DURATION), dtype=np.float32)

def audio_callback(indata, frames, time_info, status):
    global audio_buffer
    if status:
        print(f"\n[Audio Error] {status}", file=sys.stderr)
    # Roll the buffer and append new incoming frames
    audio_buffer = np.roll(audio_buffer, -len(indata))
    # Apply 3.0x gain boost to ensure quiet sounds are easily captured by model
    audio_buffer[-len(indata):] = indata[:, 0] * 3.0

def main():
    print("\033[96m====================================================\033[0m")
    print("\033[96m    AURA AI Sound Awareness Offline System          \033[0m")
    print("\033[96m    (Python Standalone Microphone Classifier)       \033[0m")
    print("\033[96m====================================================\033[0m")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(script_dir, "sound_model.tflite")
    mean_path = os.path.join(script_dir, "mean.npy")
    std_path = os.path.join(script_dir, "std.npy")
    
    if not (os.path.exists(model_path) and os.path.exists(mean_path) and os.path.exists(std_path)):
        print("\033[91mError: Model files (sound_model.tflite, mean.npy, std.npy) are missing in the folder!\033[0m")
        sys.exit(1)
        
    # Load assets
    print("Loading AI Model and normalization matrices...")
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    mean = np.load(mean_path)
    std = np.load(std_path)
    
    print("\033[92mAI Model Loaded Successfully!\033[0m")
    
    # Initialize microphone stream
    # 16kHz mono, block size of 4000 samples (250ms chunks)
    block_size = int(SAMPLE_RATE * 0.25)
    
    print("\033[96mInitializing Microphone stream...\033[0m")
    try:
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            blocksize=block_size,
            callback=audio_callback
        )
        stream.start()
        print("\033[92mRecording Active. Real-time neural inference active...\033[0m")
    except Exception as e:
        print(f"\033[91mFailed to start microphone: {e}\033[0m")
        sys.exit(1)
        
    print("\nScanning ambient sounds... (Press Ctrl+C to terminate)")
    print("\033[90m----------------------------------------------------\033[0m")
    
    # Clear console to draw dashboard
    os.system('cls' if os.name == 'nt' else 'clear')
    
    try:
        last_alert_time = 0
        current_alert = None
        
        while True:
            # 1. Grab snapshot of the 1-second buffer
            audio_data = np.copy(audio_buffer)
            
            # Calculate live RMS volume
            rms = np.sqrt(np.mean(audio_data**2))
            
            # Find peak frequency for status updates
            fft_data = np.abs(np.fft.rfft(audio_data))
            freqs = np.fft.rfftfreq(len(audio_data), 1.0 / SAMPLE_RATE)
            peak_freq = freqs[np.argmax(fft_data)]
            
            # Only run inference if there is active sound in the room
            if rms > 0.015:
                # 2. Extract 40-element mean MFCC features (matches trained model)
                mfccs = librosa.feature.mfcc(y=audio_data, sr=SAMPLE_RATE, n_mfcc=N_MFCC)
                mfccs_scaled = np.mean(mfccs.T, axis=0)
                
                # 3. Standardize MFCCs using training mean/std
                mfccs_normalized = (mfccs_scaled - mean) / std
                
                # Add batch dimension for Dense Neural Network input shape: (1, 40)
                input_data = np.expand_dims(mfccs_normalized, axis=0).astype(np.float32)
                
                # 4. Invoke TFLite Model
                interpreter.set_tensor(input_details[0]['index'], input_data)
                interpreter.invoke()
                predictions = interpreter.get_tensor(output_details[0]['index'])[0]
                
                # Extract predicted label and confidence
                pred_idx = np.argmax(predictions)
                confidence = predictions[pred_idx]
                pred_class = CLASSES[pred_idx]
            else:
                # Room is silent
                pred_class = "background_noise"
                confidence = 1.0
                predictions = np.zeros(len(CLASSES))
                predictions[-1] = 1.0
                
            # 5. Render Console HUD Dashboard
            sys.stdout.write("\033[H")  # Move cursor to top of terminal
            print("\033[96m====================================================\033[0m")
            print("\033[96m    AURA AI Sound Awareness Offline System (LIVE)   \033[0m")
            print("\033[96m====================================================\033[0m")
            print(f"  Live Mic Status: \033[92mActive\033[0m | Volume (RMS): {rms*100:4.1f}%")
            print(f"  Dominant Pitch:  {int(peak_freq):4d} Hz")
            print("\033[90m----------------------------------------------------\033[0m")
            print("  AI Neural Network Confidences:")
            
            # Print horizontal bar chart for top classes
            for idx, name in enumerate(CLASSES):
                conf = predictions[idx]
                bar_len = int(conf * 20)
                bar = "█" * bar_len + "░" * (20 - bar_len)
                
                displayName = SINHALA_MAP.get(name, name.replace("_", " ").title())
                if name == pred_class and name != "background_noise" and conf > 0.25:
                    # Highlight active detection in green
                    print(f"  {displayName:25s} [{bar}] \033[92m{conf*100:5.1f}%\033[0m")
                else:
                    print(f"  {displayName:25s} [{bar}] {conf*100:5.1f}%")
                    
            print("\033[90m----------------------------------------------------\033[0m")
            
            # 6. Check for Urgent Alert Events (Confidence > 35%)
            if pred_class != "background_noise" and confidence > 0.35:
                now_t = time.time()
                # Cooldown alerts to prevent screen flicker
                current_alert = pred_class
                last_alert_time = now_t
                
            if current_alert and (time.time() - last_alert_time < 3.0):
                color_alert = PRIORITY_COLORS.get(current_alert, current_alert.upper())
                print(f"\n  {color_alert}")
                # Print visual flashing borders
                print("  \033[91m*" * 50 + "\033[0m")
                print(f"  \033[91m* DETECTED: {current_alert.replace('_', ' ').upper():28s} *\033[0m")
                print("  \033[91m*" * 50 + "\033[0m")
            else:
                current_alert = None
                print("\n  \033[90m[ Scanning room for alerts... ]                     \033[0m")
                print("                                                      ")
                print("                                                      ")
                print("                                                      ")
                
            sys.stdout.flush()
            time.sleep(0.1)  # Refresh dashboard at 10Hz
            
    except KeyboardInterrupt:
        print("\n\nTerminating audio stream...")
        stream.stop()
        stream.close()
        print("\033[92mAURA live detector shut down safely.\033[0m")

if __name__ == "__main__":
    main()
