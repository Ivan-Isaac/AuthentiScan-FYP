import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AuthentiScanApp());
}

class AuthentiScanApp extends StatelessWidget {
  const AuthentiScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuthentiScan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isAnalyzing = false;
  List<dynamic> _detections = [];
  double _imageWidth = 0;
  double _imageHeight = 0;

  Future<void> _takePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      // Get the original image dimensions for accurate scaling
      var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());

      setState(() {
        _selectedImage = imageFile;
        _imageWidth = decodedImage.width.toDouble();
        _imageHeight = decodedImage.height.toDouble();
        _detections = []; // Clear previous boxes
        _isAnalyzing = true;
      });

      await _analyzeImage(imageFile);
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    final uri = Uri.parse('http://192.168.0.17:5000/predict');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);

        setState(() {
          // Save the detection data to our state so the CustomPainter can use it
          _detections = jsonResponse['data'];
        });

      } else {
        debugPrint("Failed to get prediction. Status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error connecting to server: $e");
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AuthentiScan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        // Added SingleChildScrollView so the new banner doesn't cause screen overflow
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _selectedImage == null
              ? const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_outlined, size: 100, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'No item scanned yet.\nTap the button below to verify an accessory.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _imageWidth,
                      height: _imageHeight,
                      child: CustomPaint(
                        foregroundPainter: BoundingBoxPainter(_detections),
                        child: Image.file(_selectedImage!, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                  if (_isAnalyzing)
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 6.0,
                    ),
                ],
              ),
              const SizedBox(height: 24), // Spacing between image and banner

              // --- THE NEW COUNTERFEIT UI LOGIC ---
              if (!_isAnalyzing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: _detections.isEmpty ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: _detections.isEmpty ? Colors.red : Colors.green,
                      width: 2.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _detections.isEmpty ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: _detections.isEmpty ? Colors.red : Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _detections.isEmpty
                            ? "WARNING: COUNTERFEIT DETECTED\n(Missing Authenticity Features)"
                            : "VERIFIED GENUINE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _detections.isEmpty ? Colors.red.shade900 : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _takePhoto,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Item'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// --- THE CUSTOM PAINTER CLASS ---
// This acts as a transparent sheet of glass over your image to draw the boxes.
class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detections;

  BoundingBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    // Set up the "pen" to draw the rectangle
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0; // Make the box thick enough to see easily

    // Set up the text style for the label
    final textStyle = const TextStyle(
      color: Colors.white,
      backgroundColor: Colors.green,
      fontSize: 40.0,
      fontWeight: FontWeight.bold,
    );

    for (var detection in detections) {
      // Extract the coordinates [x_min, y_min, x_max, y_max]
      List<dynamic> box = detection['bounding_box'];
      double xMin = box[0].toDouble();
      double yMin = box[1].toDouble();
      double xMax = box[2].toDouble();
      double yMax = box[3].toDouble();

      // Draw the rectangle
      var rect = Rect.fromLTRB(xMin, yMin, xMax, yMax);
      canvas.drawRect(rect, paint);

      // Draw the label and confidence score above the box
      double conf = detection['confidence'] * 100;
      String labelText = "${detection['label']} (${conf.toStringAsFixed(1)}%)";

      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(xMin, yMin - 45)); // Position text just above the box
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint when new data arrives
  }
}