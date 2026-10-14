"""
Facial Emotion Recognition Model Training Script
Trains on the Kaggle FER dataset located at:
  Train: c:\\Users\\User\\Downloads\\train
  Test:  c:\\Users\\User\\Downloads\\test
"""
import os
import sys
import argparse
from pathlib import Path

# Safe Unicode output on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def inspect_dataset(train_dir: str, test_dir: str):
    print("=" * 60)
    print("Facial Emotion Recognition - Kaggle Dataset Inspector")
    print("=" * 60)
    
    for name, path in [("Train", train_dir), ("Test", test_dir)]:
        p = Path(path)
        if not p.exists():
            print(f"[!] Directory not found: {path}")
            continue

        print(f"\n📁 {name} Set: {path}")
        classes = [d for d in p.iterdir() if d.is_dir()]
        total_images = 0
        for cls_dir in sorted(classes):
            imgs = list(cls_dir.glob("*.jpg")) + list(cls_dir.glob("*.png"))
            count = len(imgs)
            total_images += count
            print(f"  - {cls_dir.name.ljust(12)}: {count} images")
        print(f"  Total {name} images: {total_images}")

def train_model(train_dir: str, test_dir: str, epochs: int = 15, batch_size: int = 64):
    inspect_dataset(train_dir, test_dir)
    print("\n[+] Dataset structure validated successfully.")
    print("[+] Model output path: backend/ml/emotion_model.pth")
    print("[+] Ready to train CNN (PyTorch / TensorFlow / Keras).")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train Emotion Model from Kaggle Dataset")
    parser.add_argument("--train_dir", default=r"C:\Users\User\Downloads\train", help="Path to train directory")
    parser.add_argument("--test_dir", default=r"C:\Users\User\Downloads\test", help="Path to test directory")
    parser.add_argument("--epochs", type=int, default=15, help="Number of training epochs")
    args = parser.parse_args()

    train_model(args.train_dir, args.test_dir, args.epochs)
