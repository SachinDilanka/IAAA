/*
  LilyGO TTGO T-Wristband (ESP32) & Smartband BLE High-Intensity Vibration & Warning Notification Firmware
  
  Features:
  - 100% Offline BLE GATT Server receiver.
  - Receives priority emergency alerts & UTF-8 warning text from AcousticAware Deaf Mobile App.
  - Drives vibration motor via ESP32 PWM (ledcWrite on GPIO 4) at 100% MAXIMUM BATTERY VOLTAGE (Duty Cycle 255/255).
  - High Urgency alerts execute an INCOMING PHONE CALL CONTINUOUS RING CADENCE (1500ms ON / 50ms OFF infinite loop).
  - Renders large flashing red warning message banner on ST7735 TFT display screen.
*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <TFT_eSPI.h> // ST7735 Display Driver for TTGO T-Wristband

#define VIBRATOR_PIN     4
#define LED_PIN          2

#define PWM_CHANNEL      0
#define PWM_FREQ         5000
#define PWM_RESOLUTION   8

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

TFT_eSPI tft = TFT_eSPI();

enum PriorityLevel {
  VIB_STOP = 0,
  VIB_LOW = 1,
  VIB_MEDIUM = 2,
  VIB_HIGH = 3
};

PriorityLevel currentPriority = VIB_STOP;
bool deviceConnected = false;
String lastWarningText = "AcousticAware Ready";

// Incoming Phone Call Cadence: Continuous 1500ms ON / 50ms OFF loop at 100% PWM
int patternLow[]    = { 200, 100, 200, 100, 200, 400 };
int patternMedium[] = { 600, 100, 600, 300, 600, 100 };
int patternHigh[]   = { 1500, 50, 1500, 50, 1500, 50, 1500, 50 }; // Continuous Call Ringing Cadence

int* activePattern = nullptr;
int activePatternLen = 0;
int currentPatternStep = 0;
unsigned long stepStartTime = 0;
bool motorState = false;
int targetDutyCycle = 255; // 255 = 100% Max intensity

void startVibrationPattern(PriorityLevel level, int dutyCycle = 255);
void updateVibration();
void updateDisplay(String warningMsg, PriorityLevel level);

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Mobile App connected via BLE!");
      updateDisplay("BLE CONNECTED!", VIB_LOW);
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Mobile App disconnected. Restarting advertising...");
      startVibrationPattern(VIB_STOP);
      updateDisplay("BLE DISCONNECTED", VIB_STOP);
      pServer->getAdvertising()->start();
    }
};

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      if (value.length() > 0) {
        uint8_t header = (uint8_t)value[0];

        if (value.length() == 1) {
          PriorityLevel p = (PriorityLevel)header;
          startVibrationPattern(p, p == VIB_HIGH ? 255 : (p == VIB_MEDIUM ? 200 : 140));
          updateDisplay(p == VIB_HIGH ? "HIGH SOS CALL ALERT!" : (p == VIB_MEDIUM ? "MEDIUM ALERT" : "NOTICE"), p);
          return;
        }

        if (header == 0xA5 && value.length() >= 5) {
          uint8_t priorityByte = (uint8_t)value[1];
          uint8_t dutyByte = (uint8_t)value[3];
          uint8_t textLen = (uint8_t)value[4];

          String warningMsg = "EMERGENCY CALL ALERT!";
          if (value.length() >= 5 + textLen) {
            warningMsg = "";
            for (size_t i = 5; i < 5 + textLen; i++) {
              warningMsg += (char)value[i];
            }
          }

          PriorityLevel p = (PriorityLevel)priorityByte;
          startVibrationPattern(p, 255); // Force 100% max intensity
          updateDisplay(warningMsg, p);
        }
      }
    }
};

void setup() {
  Serial.begin(115200);

  // Configure LEDC PWM for vibration motor driving
  ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
  ledcAttachPin(VIBRATOR_PIN, PWM_CHANNEL);
  ledcWrite(PWM_CHANNEL, 0);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize TFT Display Screen
  tft.init();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.setTextSize(2);
  tft.setCursor(5, 5);
  tft.println("AcousticAware");
  tft.setTextSize(1);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setCursor(5, 30);
  tft.println("TTGO T-Wristband DEAF AI");
  tft.setCursor(5, 45);
  tft.println("Status: BLE Scanning...");

  // Initialize BLE Server
  BLEDevice::init("TTGO-T-Wristband");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_WRITE |
                                         BLECharacteristic::PROPERTY_WRITE_NR
                                       );
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("TTGO T-Wristband BLE Server Ready!");
}

void loop() {
  updateVibration();
  delay(10);
}

void startVibrationPattern(PriorityLevel level, int dutyCycle) {
  currentPriority = level;
  currentPatternStep = 0;
  stepStartTime = millis();
  targetDutyCycle = 255; // Always 100% max intensity for skin feeling

  switch (level) {
    case VIB_STOP:
      activePattern = nullptr;
      activePatternLen = 0;
      motorState = false;
      ledcWrite(PWM_CHANNEL, 0);
      digitalWrite(LED_PIN, LOW);
      break;

    case VIB_LOW:
      activePattern = patternLow;
      activePatternLen = sizeof(patternLow) / sizeof(patternLow[0]);
      motorState = true;
      ledcWrite(PWM_CHANNEL, targetDutyCycle);
      digitalWrite(LED_PIN, HIGH);
      break;

    case VIB_MEDIUM:
      activePattern = patternMedium;
      activePatternLen = sizeof(patternMedium) / sizeof(patternMedium[0]);
      motorState = true;
      ledcWrite(PWM_CHANNEL, targetDutyCycle);
      digitalWrite(LED_PIN, HIGH);
      break;

    case VIB_HIGH:
      activePattern = patternHigh;
      activePatternLen = sizeof(patternHigh) / sizeof(patternHigh[0]);
      motorState = true;
      ledcWrite(PWM_CHANNEL, 255); // 100% Max battery voltage drive
      digitalWrite(LED_PIN, HIGH);
      break;
  }
}

void updateVibration() {
  if (activePattern == nullptr || activePatternLen == 0) return;

  unsigned long elapsed = millis() - stepStartTime;
  unsigned long currentStepDuration = activePattern[currentPatternStep];

  if (elapsed >= currentStepDuration) {
    currentPatternStep++;

    if (currentPatternStep >= activePatternLen) {
      if (currentPriority == VIB_HIGH) {
        currentPatternStep = 0; // Infinite continuous call ringing pulse for High Priority
      } else {
        startVibrationPattern(VIB_STOP);
        return;
      }
    }

    motorState = (currentPatternStep % 2 == 0);
    ledcWrite(PWM_CHANNEL, motorState ? 255 : 0);
    digitalWrite(LED_PIN, motorState ? HIGH : LOW);
    stepStartTime = millis();
  }
}

void updateDisplay(String warningMsg, PriorityLevel level) {
  lastWarningText = warningMsg;
  tft.fillScreen(level == VIB_HIGH ? TFT_RED : (level == VIB_MEDIUM ? TFT_ORANGE : TFT_NAVY));

  tft.setTextColor(TFT_WHITE, level == VIB_HIGH ? TFT_RED : (level == VIB_MEDIUM ? TFT_ORANGE : TFT_NAVY));
  tft.setTextSize(2);
  tft.setCursor(5, 5);

  if (level == VIB_HIGH) {
    tft.println("🚨 CALL SOS!");
  } else if (level == VIB_MEDIUM) {
    tft.println("⚠️ WARNING!");
  } else {
    tft.println("NOTICE");
  }

  tft.setTextSize(1);
  tft.setCursor(5, 30);
  tft.println(warningMsg);
  tft.setCursor(5, 50);
  tft.println("100% PWM CALL VIBE ON");
}
