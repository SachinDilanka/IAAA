"""
Real-time Webcam Emotion Detector with Sinhala Speech Therapy Feedback
Uses trained FER-2013 model and OpenCV Face Detection.
"""

import cv2
import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
from torchvision import transforms
from train_fer2013 import EmotionCNN, SINHALA_EMOTION_MAP, MODEL_SAVE_PATH

def run_webcam():
    # Load model
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    checkpoint = torch.load(MODEL_SAVE_PATH, map_location=device)
    classes = checkpoint["classes"]

    model = EmotionCNN(num_classes=len(classes)).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    # Preprocessing transform
    transform = transforms.Compose([
        transforms.Grayscale(num_output_channels=1),
        transforms.Resize((48, 48)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.5], std=[0.5])
    ])

    # OpenCV Haar Cascade face detector
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    cap = cv2.VideoCapture(0)

    print("Webcam started! Press 'q' to quit.")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1) # Mirror reflection
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=5, minSize=(60, 60))

        for (x, y, w, h) in faces:
            # Crop face
            face_roi = gray[y:y+h, x:x+w]
            pil_img = Image.fromarray(face_roi)
            tensor_img = transform(pil_img).unsqueeze(0).to(device)

            with torch.no_grad():
                outputs = model(tensor_img)
                probs = F.softmax(outputs, dim=1)[0]
                conf, pred_idx = torch.max(probs, 0)

            emotion = classes[pred_idx.item()]
            conf_val = conf.item() * 100.0
            info = SINHALA_EMOTION_MAP.get(emotion.lower(), {})

            # Draw bounding box and HUD text
            cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 128), 2)
            display_text = f"{emotion.capitalize()} ({conf_val:.0f}%)"
            cv2.putText(frame, display_text, (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 128), 2)

        cv2.imshow("Kaggle FER-2013 Sinhala Speech Therapy", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_webcam()
