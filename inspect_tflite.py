import os
import tensorflow as tf

def inspect_model(path, title):
    print("=" * 60)
    print(f"MODEL: {title}")
    print(f"PATH:  {path}")
    if not os.path.exists(path):
        print("Status: File not found")
        return
    size_kb = os.path.getsize(path) / 1024
    print(f"SIZE:  {size_kb:.2f} KB")
    
    try:
        interpreter = tf.lite.Interpreter(model_path=path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("\n--- INPUT TENSOR ---")
        for i, inp in enumerate(input_details):
            print(f"  [{i}] Name:  {inp['name']}")
            print(f"      Shape: {inp['shape']}")
            print(f"      Type:  {inp['dtype'].__name__}")
            
        print("\n--- OUTPUT TENSOR ---")
        for i, out in enumerate(output_details):
            print(f"  [{i}] Name:  {out['name']}")
            print(f"      Shape: {out['shape']}")
            print(f"      Type:  {out['dtype'].__name__}")
            
        print("Status: Valid & Functional TensorFlow Lite Model")
    except Exception as e:
        print(f"Error inspecting: {e}")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    inspect_model("ml_pipeline/models/sound_classifier.tflite", "CNN Classifier (Google Colab)")
    inspect_model("model-training/sound_model.tflite", "DNN Sound Classifier (Local)")

