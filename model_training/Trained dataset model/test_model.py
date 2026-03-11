from ultralytics import YOLO

# 1. Load your custom-trained MVP model
model = YOLO("pn920_mvp_v1.pt")

# 2. Run inference on a test photo 
# (Place a photo named 'test_image.jpg' in the same folder)
results = model("test_image.jpg", conf=0.02) # conf=0.25 ignores weak guesses

# 3. Display the result on your screen
results[0].show()

# 4. Save a copy of the image with the bounding boxes drawn on it
results[0].save("output_result.jpg")