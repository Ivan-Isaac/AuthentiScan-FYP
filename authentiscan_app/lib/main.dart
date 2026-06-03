import 'dart:io';
import 'dart:convert';
import 'dart:async'; //TimeoutException
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Get global list of available cameras
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
  bool _isFlashOn = false;

  String? _errorMessage;

  // Default to localhost, changeable in the server settings dialog
  String _serverBaseUrl = "http://192.168.0.17:5000";
  final TextEditingController _urlController = TextEditingController();

  // --- SERVER SETTINGS DIALOG ---
  Future<void> _showSettingsDialog() async {
    _urlController.text = _serverBaseUrl; // Pre-fill with current URL

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Server Configuration'),
          content: TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: "Base URL (e.g., https://192.168.1.1)",
            ),
            keyboardType: TextInputType.url,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                String updatedUrl = _urlController.text.trim().replaceAll(RegExp(r'/$'), '');

                // Save the URL to device storage
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('saved_server_url', updatedUrl);

                setState(() {
                  // Strip any trailing slashes just to be safe
                  _serverBaseUrl = _urlController.text.trim().replaceAll(RegExp(r'/$'), '');
                });

                // Check if context is mounted before popping (best practice for async dialogs)
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Look for the saved URL. If it doesn't exist (first time opening app),
      // it defaults to the placeholder IP.
      _serverBaseUrl = prefs.getString('saved_server_url') ?? "http://192.168.0.17:5000";
    });
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    
    // Force auto focus
    await _cameraController!.setFocusMode(FocusMode.auto);
    // Force the flash to be OFF by default when the app opens
    await _cameraController!.setFlashMode(FlashMode.off);

    if (mounted) {
      setState(() {});
    }
  }

  // --- FLASH TOGGLE FUNCTION ---
  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    // Switch between 'always' on and 'off'
    await _cameraController!.setFlashMode(
      _isFlashOn ? FlashMode.always : FlashMode.off,
    );
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
      _errorMessage = null; // Clear errors from previous session
      _isAnalyzing = true;
    });

    await _analyzeImage(imageFile);
  }
  // -- POST TO SERVER API FOR TRAINING --
  Future<void> _analyzeImage(File imageFile) async {
    final uri = Uri.parse('$_serverBaseUrl/predict');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("The connection to the AuthentiScan server timed out.");
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        setState(() {
          _detections = jsonResponse['data'];
        });
      } else {
        debugPrint("Failed to get prediction. Status Code: ${response.statusCode}");
        setState(() {
          _errorMessage = "SERVER ERROR\nGot status code ${response.statusCode}.";
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        _errorMessage = "CONNECTION TIMEOUT\nPlease check if the Flask server is running and your IP is correct.";
      });
    } catch (e) {
      debugPrint("Error connecting to server: $e");
      setState(() {
        _errorMessage = "NETWORK ERROR\nCould not reach the server.";
      });
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
    return PopScope(
      // canPop decides if the app is allowed to close.
      // It can ONLY close if there is no image currently selected (meaning we are on the camera feed).
      canPop: _selectedImage == null,

      onPopInvoked: (bool didPop) {
        // If didPop is true, it means the app successfully closed (we were on the camera feed).
        // We don't need to do anything.
        if (didPop) {
          return;
        }

        // If didPop is false, the PopScope prevented the app from closing.
        // This means we are on the results screen, so we trigger the reset function instead!
        _resetScanner();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AuthentiScan', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsDialog, // Opens the pop-up
            )
          ],
        ),
        backgroundColor: Colors.black, // Better background for a camera app
        body: _selectedImage == null
            ? _buildCameraFeed()
            : _buildResultsScreen(),
      ),
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
              // Flash Toggle button
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // UI STATE 2: THE ANALYSIS RESULTS
  Widget _buildResultsScreen() {

    // --- THE NEW 3-STATE LOGIC CHECK ---
    bool hasFake = _detections.any((d) => d['label'].toString().toLowerCase().contains('fake'));
    bool hasReal = _detections.any((d) =>
    d['label'].toString().toLowerCase().contains('real') ||
        d['label'].toString().toLowerCase().contains('genuine'));

    // Set UI variables based on what the AI found
    Color boxColor;
    Color iconColor;
    IconData statusIcon;
    String statusText;

    // Choose message based on State
    if (_errorMessage != null) {
      // STATE 4: Network connection error
      boxColor = Colors.grey.shade200;
      iconColor = Colors.red.shade800;
      statusIcon = Icons.wifi_off_rounded;
      statusText = _errorMessage!;
    } else if (hasFake) {
      // STATE 1: Found known fake features
      boxColor = Colors.red.shade50;
      iconColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
      statusText = "WARNING: COUNTERFEIT DETECTED\n(Fake Features Identified)";
    } else if (hasReal) {
      // STATE 2: Found known real features
      boxColor = Colors.green.shade50;
      iconColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusText = "VERIFIED GENUINE\n(Authentic Markings Found)";
    } else {
      // STATE 3: Found nothing
      boxColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade800;
      statusIcon = Icons.help_outline;
      statusText = "NO MARKINGS DETECTED\nPlease scan a supported item, or the item may be missing authentic features.";
    }

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
                        foregroundPainter: BoundingBoxPainter(_detections, MediaQuery.of(context).size.width),
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
              // --- THE UPDATED DYNAMIC CONTAINER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: iconColor, width: 2.0),
                  ),
                  child: Column(
                    children: [
                      Icon(statusIcon, color: iconColor, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
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
  final double screenWidth; // Added screenWidth variable

  // Require screenWidth in the constructor
  BoundingBoxPainter(this.detections, this.screenWidth);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calculate the exact scale factor Flutter is applying to fit the image on screen
    double scaleFactor = screenWidth / size.width;

    // 2. INVERSE SCALING: Divide your desired visual size by the scale factor.
    // This guarantees the text is exactly 14 logical pixels on your physical phone screen.
    final double dynamicStrokeWidth = 3.0 / scaleFactor;
    final double dynamicFontSize = 14.0 / scaleFactor;
    final double textPadding = 4.0 / scaleFactor;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = dynamicStrokeWidth;

    final textStyle = TextStyle(
      color: Colors.white,
      backgroundColor: Colors.green,
      fontSize: dynamicFontSize,
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

      textPainter.paint(canvas, Offset(xMin, yMin - textPainter.height - textPadding));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}