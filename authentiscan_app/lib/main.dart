import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

// We need a global list of available cameras
List<CameraDescription> cameras = [];

Future<void> main() async {
  // Ensure Flutter is initialized before checking hardware
  WidgetsFlutterBinding.ensureInitialized();
  // Fetch the available cameras on the device
  cameras = await availableCameras();

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
  CameraController? _cameraController;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isAnalyzing = false;
  List<dynamic> _detections = [];
  double _imageWidth = 0;
  double _imageHeight = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;

    // Initialize the first camera (usually the back camera)
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // --- CAPTURE FROM LIVE FEED ---
  Future<void> _captureFromCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile picture = await _cameraController!.takePicture();
      _processSelectedFile(File(picture.path));
    } catch (e) {
      debugPrint("Error capturing image: $e");
    }
  }

  // --- CAPTURE FROM GALLERY ---
  Future<void> _pickFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _processSelectedFile(File(pickedFile.path));
    }
  }

  // --- PREPARE IMAGE AND SEND TO FLASK ---
  Future<void> _processSelectedFile(File imageFile) async {
    var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());

    setState(() {
      _selectedImage = imageFile;
      _imageWidth = decodedImage.width.toDouble();
      _imageHeight = decodedImage.height.toDouble();
      _detections = [];
      _isAnalyzing = true;
    });

    await _analyzeImage(imageFile);
  }
  // POST to server api for image analyze from trained model
  Future<void> _analyzeImage(File imageFile) async {
    final uri = Uri.parse('http://192.168.0.17:5000/predict'); // Change to server host ip address
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          _detections = jsonResponse['data'];
        });
      } else {
        debugPrint("Failed to get prediction.");
      }
    } catch (e) {
      debugPrint("Error connecting to server: $e");
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // --- RESET TO LIVE FEED ---
  void _resetScanner() {
    setState(() {
      _selectedImage = null;
      _detections = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AuthentiScan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      backgroundColor: Colors.black, // Better background for a camera app
      body: _selectedImage == null
          ? _buildCameraFeed()
          : _buildResultsScreen(),
    );
  }

  // UI STATE 1: THE LIVE CAMERA FEED
  Widget _buildCameraFeed() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                )
            ),
            child: CameraPreview(_cameraController!),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery Button
              IconButton(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
              ),
              // Main Capture Button
              GestureDetector(
                onTap: _captureFromCamera,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white30,
                  ),
                  child: const Icon(Icons.camera, color: Colors.white, size: 40),
                ),
              ),
              // Placeholder for layout balance
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }

  // UI STATE 2: THE ANALYSIS RESULTS
  Widget _buildResultsScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
                    const CircularProgressIndicator(color: Colors.white, strokeWidth: 6.0),
                ],
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              // Button to clear results and go back to camera
              ElevatedButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.refresh),
                label: const Text("Scan Another Item"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- THE CUSTOM PAINTER CLASS ---
class BoundingBoxPainter extends CustomPainter {
  final List<dynamic> detections;

  BoundingBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final textStyle = const TextStyle(
      color: Colors.white,
      backgroundColor: Colors.green,
      fontSize: 40.0,
      fontWeight: FontWeight.bold,
    );

    for (var detection in detections) {
      List<dynamic> box = detection['bounding_box'];
      double xMin = box[0].toDouble();
      double yMin = box[1].toDouble();
      double xMax = box[2].toDouble();
      double yMax = box[3].toDouble();

      var rect = Rect.fromLTRB(xMin, yMin, xMax, yMax);
      canvas.drawRect(rect, paint);

      double conf = detection['confidence'] * 100;
      String labelText = "${detection['label']} (${conf.toStringAsFixed(1)}%)";

      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(xMin, yMin - 45));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}