import cv2
import json
import sys
import os
import mediapipe as mp

from mediapipe.tasks import python
from mediapipe.tasks.python import vision

def process_video(video_path, output_json_path):
    if not os.path.isfile(video_path):
        raise FileNotFoundError(f"Video file not found: '{video_path}'.")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(script_dir, "hand_landmarker.task")
    if not os.path.isfile(model_path):
        raise FileNotFoundError(f"Hand landmark model not found: '{model_path}'.")

    base_options = python.BaseOptions(model_asset_path=model_path)
    options = vision.HandLandmarkerOptions(
        base_options=base_options,
        num_hands=2,  # Support 2-handed SSL signs!
        min_hand_detection_confidence=0.3,
        min_hand_presence_confidence=0.3,
        min_tracking_confidence=0.3
    )
    detector = vision.HandLandmarker.create_from_options(options)
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        detector.close()
        raise ValueError(f"Could not open video file: '{video_path}'.")

    sequence_data = []
    try:
        print(f"Processing video: {video_path}...")

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            timestamp_ms = cap.get(cv2.CAP_PROP_POS_MSEC)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
            detection_result = detector.detect(mp_image)

            hands_in_frame = []
            if detection_result.hand_landmarks:
                for hand_idx, hand_landmarks in enumerate(
                    detection_result.hand_landmarks
                ):
                    label = "Unknown"
                    if (
                        detection_result.handedness
                        and len(detection_result.handedness) > hand_idx
                    ):
                        label = detection_result.handedness[hand_idx][0].category_name

                    landmarks_list = [
                        {
                            "id": idx,
                            "x": round(lm.x, 4),
                            "y": round(lm.y, 4),
                            "z": round(lm.z, 4),
                        }
                        for idx, lm in enumerate(hand_landmarks)
                    ]
                    hands_in_frame.append({
                        "handLabel": label,
                        "landmarks": landmarks_list,
                    })

            if hands_in_frame:
                sequence_data.append({
                    "frameIndex": len(sequence_data),
                    "timestampMs": round(timestamp_ms, 2),
                    "hands": hands_in_frame,
                })
    finally:
        cap.release()
        detector.close()

    if not sequence_data:
        print(f"No hand landmarks detected in '{video_path}'.")
        return 0

    output_dir = os.path.dirname(os.path.abspath(output_json_path))
    os.makedirs(output_dir, exist_ok=True)
    with open(output_json_path, "w", encoding="utf-8") as output_file:
        json.dump(sequence_data, output_file, indent=2)

    print(
        f"Done! Extracted {len(sequence_data)} frames with multi-hand support "
        f"to: {output_json_path}"
    )
    return len(sequence_data)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python scripts/extract_landmarks.py <video_file> <output_json>")
    else:
        process_video(sys.argv[1], sys.argv[2])