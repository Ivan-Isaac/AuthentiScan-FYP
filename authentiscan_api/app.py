from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from ultralytics import YOLO
import os

app = Flask(__name__)

# Load the MVP model
model = YOLO("ver4_1-6-2026") 

@app.route('/predict', methods=['POST'])
def predict():
    # 1. Check if the request contains an image file
    if 'image' not in request.files:
        return jsonify({"error": "No image part in the request"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    # 2. Save the incoming image temporarily
    filename = secure_filename(file.filename)
    filepath = os.path.join("temp_uploads", filename)
    file.save(filepath)

    # 3. Run YOLO inference (Confidence at 60%)
    results = model(filepath, conf=0.60)
    
    # 4. Extract the data to send back to Flutter
    detections = []
    for r in results:
        for box in r.boxes:
            # Get box coordinates (x_min, y_min, x_max, y_max) and confidence
            coords = box.xyxy[0].tolist() 
            conf = float(box.conf[0])
            
            # -- Get the actual label from YOLO ---
            class_id = int(box.cls[0])
            class_name = model.names[class_id] 
            
            detections.append({
                "label": class_name, 
                "confidence": round(conf, 4),
                "bounding_box": coords
            })

    # 5. Delete the temporary image to save space
    os.remove(filepath)

    # 6. Return the JSON response
    return jsonify({
        "status": "success",
        "total_detections": len(detections),
        "data": detections
    })

if __name__ == '__main__':
    # Create the temporary upload folder if it doesn't exist
    if not os.path.exists("temp_uploads"):
        os.makedirs("temp_uploads")
        
    # host='0.0.0.0' allows your phone to connect to your laptop's IP address later
    app.run(host='0.0.0.0', port=5000, debug=True)