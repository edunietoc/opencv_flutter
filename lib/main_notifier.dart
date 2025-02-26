import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'conver/func.dart';

import 'package:image/image.dart' as imglib;

import 'models/face_result.dart';

class MyNotifier extends ChangeNotifier {
  MyNotifier() {
    initState();
  }

  List<CameraDescription> _cameras = [];

  Future<void> initState() async {
    _cameras = await availableCameras();
    await _setCameraController();
    await _getModelFromAssets();
    _getImageData();
    notifyListeners();
  }

  Future<void> _getModelFromAssets() async {
    final model =
        await rootBundle.load('assets/face_detection_yunet_2023mar.onnx');

    _modelBuffer = model.buffer.asUint8List();
    _modelLoaded = true;
    notifyListeners();
  }

  cv.FaceDetectorYN? faceDetectorYN;
  Uint8List _modelBuffer = Uint8List(0);
  bool _modelLoaded = false;

  late CameraController _cameraController;
  CameraController get cameraController => _cameraController;

  Future<void> _setCameraController() async {
    _cameraController = CameraController(
      _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front),
      ResolutionPreset.low,
      // imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController.initialize();
    _cameraIsInitialized = _cameraController.value.isInitialized;
    notifyListeners();
  }

  bool _cameraIsInitialized = false;
  bool get cameraIsInitialized => _cameraIsInitialized;

  bool get showProcessedPreview => false;

  Uint8List _imageData = Uint8List(0);
  Uint8List get imageData => _imageData;

  bool _captureStaticImage = false;
  bool _captureStaticImage2 = false;

  FaceResult? _faceResult;
  FaceResult? get faceResult => _faceResult;

  int _skipFrame = 2;
  int _frameCount = 0;

  Future<void> _getImageData() async {
    await _cameraController.startImageStream((image) async {
      _frameCount++;
      if (_frameCount % _skipFrame != 0) {
        return;
      }

      if (_frameCount > 1000) {
        _frameCount = 0;
      }

      imglib.Image convertedImg = ImageUtils.convertCameraImage(image);
      Uint8List byteData = imglib.encodeJpg(convertedImg);
      cv.Mat mat = cv.imdecode(byteData, cv.IMREAD_COLOR);

      mat = mat.rotate(cv.ROTATE_90_COUNTERCLOCKWISE);

      mat = cv.resize(mat, (320, 320));
      _faceResult = detectFace(mat);
      if (_faceResult != null) {
        notifyListeners();
      }
    });
  }

  void printMat(cv.Mat mat) {
    if (mat.cols > 0) {
      print('score: ${mat.atPixel(0, 14)}');
    }
  }

  void getImage() {
    _captureStaticImage = true;
    notifyListeners();
  }

  void getImage2() {
    _captureStaticImage2 = true;
    notifyListeners();
  }

  FaceResult? detectFace(cv.Mat mat) {
    if (!_modelLoaded) {
      print('MODEL NOT READY!!!!!');
      return null;
    }
    faceDetectorYN ??= cv.FaceDetectorYN.fromBuffer(
      "onnx",
      _modelBuffer,
      Uint8List(0),
      (mat.width, mat.height), //320, 320
    );

    cv.Mat? result = faceDetectorYN?.detect(mat);
    print('mat_result: ${result?.toFmtString()}');
    if (result == null) {
      return null;
    }

    FaceResult? resultModel = FaceResult.getModel(result);
    return resultModel;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
