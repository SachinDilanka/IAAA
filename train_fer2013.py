"""
FER-2013 Facial Emotion Recognition Model Training & Inference
Dataset paths:
- Train: C:\\Users\\User\\Downloads\\train
- Test:  C:\\Users\\User\\Downloads\\test

Supports: PyTorch CNN training and real-time evaluation with Sinhala Speech Therapy mapping.
"""

import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from PIL import Image

# 1. Path Configuration
TRAIN_DIR = r"C:\Users\User\Downloads\train"
TEST_DIR = r"C:\Users\User\Downloads\test"
MODEL_SAVE_PATH = "fer2013_emotion_model.pth"

# 2. Hyperparameters
BATCH_SIZE = 64
EPOCHS = 15
LEARNING_RATE = 0.001
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# 3. Emotion Mapping to Sinhala & Therapy Feedback
SINHALA_EMOTION_MAP = {
    "angry": {"sinhala": "කේන්තියි", "emoji": "😠", "advice": "සිනහවෙමින් සෙමින් අකුරු පුරුදු වෙමු! 😊"},
    "disgust": {"sinhala": "අකමැතියි", "emoji": "😣", "advice": "වෙනත් වචනයක් තෝරාගෙන සතුටින් කරමු! 🌸"},
    "fear": {"sinhala": "බයයි", "emoji": "😨", "advice": "බිය නැති කරමින් සෙමින් උත්සාහ කරමු! 🤗"},
    "happy": {"sinhala": "සතුටුයි", "emoji": "😊", "advice": "විශිෂ්ට සිනහවක්! දිගටම පුහුණු වෙමු! 🌟"},
    "neutral": {"sinhala": "සාමාන්‍යයි", "emoji": "😐", "advice": "මුඛය හොඳින් විවෘත කර ශබ්දය නඟන්න! 👍"},
    "sad": {"sinhala": "දුකයි", "emoji": "🥺", "advice": "කමක් නෑ, සෙමින් නැවත උත්සාහ කරමු! 💖"},
    "surprise": {"sinhala": "පුදුමයි", "emoji": "😮", "advice": "හොඳ අවධානයක්! දැන් ශබ්දය කියමු! 🎈"}
}

# 4. Data Transformations (Augmentation & Normalization)
train_transform = transforms.Compose([
    transforms.Grayscale(num_output_channels=1),
    transforms.Resize((48, 48)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(10),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.5], std=[0.5])
])

test_transform = transforms.Compose([
    transforms.Grayscale(num_output_channels=1),
    transforms.Resize((48, 48)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.5], std=[0.5])
])

# 5. Convolutional Neural Network (CNN) Architecture
class EmotionCNN(nn.Module):
    def __init__(self, num_classes=7):
        super(EmotionCNN, self).__init__()

        # Block 1
        self.conv1 = nn.Sequential(
            nn.Conv2d(1, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.MaxPool2d(2, 2), # 24x24
            nn.Dropout(0.25)
        )

        # Block 2
        self.conv2 = nn.Sequential(
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
            nn.Conv2d(128, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
            nn.MaxPool2d(2, 2), # 12x12
            nn.Dropout(0.25)
        )

        # Block 3
        self.conv3 = nn.Sequential(
            nn.Conv2d(128, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(),
            nn.MaxPool2d(2, 2), # 6x6
            nn.Dropout(0.25)
        )

        # Fully Connected Classifier
        self.fc = nn.Sequential(
            nn.Linear(256 * 6 * 6, 512),
            nn.BatchNorm1d(512),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(512, num_classes)
        )

    def forward(self, x):
        x = self.conv1(x)
        x = self.conv2(x)
        x = self.conv3(x)
        x = x.view(x.size(0), -1)
        x = self.fc(x)
        return x

def train_model():
    print(f"Using device: {DEVICE}")
    print(f"Loading training data from: {TRAIN_DIR}")
    print(f"Loading testing data from:  {TEST_DIR}")

    # Load Datasets
    train_dataset = datasets.ImageFolder(root=TRAIN_DIR, transform=train_transform)
    test_dataset = datasets.ImageFolder(root=TEST_DIR, transform=test_transform)

    classes = train_dataset.classes
    print(f"Detected Emotion Classes ({len(classes)}): {classes}")

    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, num_workers=0)
    test_loader = DataLoader(test_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

    model = EmotionCNN(num_classes=len(classes)).to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=2)

    best_accuracy = 0.0

    print("\n--- Starting Model Training ---")
    for epoch in range(EPOCHS):
        model.train()
        running_loss = 0.0
        correct_train = 0
        total_train = 0

        for images, labels in train_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * images.size(0)
            _, predicted = torch.max(outputs, 1)
            total_train += labels.size(0)
            correct_train += (predicted == labels).sum().item()

        epoch_loss = running_loss / total_train
        train_acc = (correct_train / total_train) * 100.0

        # Validation / Testing
        model.eval()
        correct_test = 0
        total_test = 0
        with torch.no_grad():
            for images, labels in test_loader:
                images, labels = images.to(DEVICE), labels.to(DEVICE)
                outputs = model(images)
                _, predicted = torch.max(outputs, 1)
                total_test += labels.size(0)
                correct_test += (predicted == labels).sum().item()

        test_acc = (correct_test / total_test) * 100.0
        scheduler.step(test_acc)

        print(f"Epoch [{epoch+1:02d}/{EPOCHS:02d}] - Loss: {epoch_loss:.4f} | Train Acc: {train_acc:.2f}% | Test Acc: {test_acc:.2f}%")

        if test_acc > best_accuracy:
            best_accuracy = test_acc
            torch.save({
                "model_state_dict": model.state_dict(),
                "classes": classes,
                "accuracy": best_accuracy
            }, MODEL_SAVE_PATH)
            print(f"  --> Saved new best model to '{MODEL_SAVE_PATH}' ({best_accuracy:.2f}%)")

    print(f"\nTraining Complete! Best Test Accuracy: {best_accuracy:.2f}%")
    print(f"Model saved at: {os.path.abspath(MODEL_SAVE_PATH)}")

def predict_single_image(image_path: str):
    """Function to predict emotion for a single face image"""
    if not os.path.exists(MODEL_SAVE_PATH):
        print(f"Model file '{MODEL_SAVE_PATH}' not found. Please train the model first.")
        return

    checkpoint = torch.load(MODEL_SAVE_PATH, map_location=DEVICE)
    classes = checkpoint["classes"]

    model = EmotionCNN(num_classes=len(classes)).to(DEVICE)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    image = Image.open(image_path)
    tensor_img = test_transform(image).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        output = model(tensor_img)
        probabilities = torch.nn.functional.softmax(output, dim=1)[0]
        confidence, predicted_idx = torch.max(probabilities, 0)

    emotion_name = classes[predicted_idx.item()]
    conf_pct = confidence.item() * 100.0
    info = SINHALA_EMOTION_MAP.get(emotion_name.lower(), {})

    print("\n--- Prediction Result ---")
    print(f"Detected Emotion: {emotion_name.capitalize()} {info.get('emoji', '')}")
    print(f"Sinhala:          {info.get('sinhala', '')}")
    print(f"Confidence:       {conf_pct:.2f}%")
    print(f"Therapy Advice:   {info.get('advice', '')}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--predict":
        img = sys.argv[2] if len(sys.argv) > 2 else r"C:\Users\User\Downloads\test\happy\PrivateTest_218533.jpg"
        predict_single_image(img)
    else:
        train_model()
