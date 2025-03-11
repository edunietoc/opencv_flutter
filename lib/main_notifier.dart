import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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

  int _indexCamera = 0;

  Future<void> _setCameraController() async {
    _indexCamera = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);

    _cameraController = CameraController(
      _cameras[_indexCamera],
      ResolutionPreset.low,
    );

    await _cameraController.initialize();
    _cameraIsInitialized = _cameraController.value.isInitialized;
    notifyListeners();
  }

  bool _cameraIsInitialized = false;
  bool get cameraIsInitialized => _cameraIsInitialized;

  bool get showProcessedPreview => false;

  FaceResult? _faceResult;
  FaceResult? get faceResult => _faceResult;

  final int _skipFrame = 2;
  int _frameCount = 0;

  final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
    enableLandmarks: true,
    enableClassification: true,
  ));

  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  double leftEyeOpenProbability = 0.0;
  double rightEyeOpenProbability = 0.0;
  double smilingProbability = 0.0;
  double yAngle = 0.0;

  Future<void> _getImageData() async {
    await _cameraController.startImageStream((image) async {
      _frameCount++;
      if (_frameCount % _skipFrame != 0) {
        return;
      }

      if (_frameCount > 1000) {
        _frameCount = 0;
      }

      final InputImage? inputImage = cameraImageToInputImage(
          image, _cameras[_indexCamera], _deviceOrientation);

      if (inputImage == null) {
        print('inputImage is null');
        return;
      }

      final List<Face> faces = await faceDetector.processImage(inputImage);

      if (faces.length > 0) {
        print('face detected');
        Face face = faces.first;

        leftEyeOpenProbability = face.leftEyeOpenProbability ?? -1;
        rightEyeOpenProbability = face.rightEyeOpenProbability ?? -1;
        smilingProbability = face.smilingProbability ?? -1;
        yAngle = face.headEulerAngleY ?? -1;
        notifyListeners();
      }

/*       cv.Mat mat = cv.imdecode(byteData, cv.IMREAD_COLOR);

      mat = mat.rotate(cv.ROTATE_90_COUNTERCLOCKWISE);

      mat = cv.resize(mat, (320, 320));
      _faceResult = detectFace(mat);
      if (_faceResult != null) {
        notifyListeners();
      } */
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}

extension Nv21Converter on CameraImage {
  Uint8List getNv21Uint8List() {
    var width = this.width;
    var height = this.height;

    var yPlane = planes[0];
    var uPlane = planes[1];
    var vPlane = planes[2];

    var yBuffer = yPlane.bytes;
    var uBuffer = uPlane.bytes;
    var vBuffer = vPlane.bytes;

    var numPixels = (width * height * 1.5).toInt();
    var nv21 = List<int>.filled(numPixels, 0);

    // Full size Y channel and quarter size U+V channels.
    int idY = 0;
    int idUV = width * height;
    var uvWidth = width ~/ 2;
    var uvHeight = height ~/ 2;
    // Copy Y & UV channel.
    // NV21 format is expected to have YYYYVU packaging.
    // The U/V planes are guaranteed to have the same row stride and pixel stride.
    // getRowStride analogue??
    var uvRowStride = uPlane.bytesPerRow;
    // getPixelStride analogue
    var uvPixelStride = uPlane.bytesPerPixel ?? 0;
    var yRowStride = yPlane.bytesPerRow;
    var yPixelStride = yPlane.bytesPerPixel ?? 0;

    for (int y = 0; y < height; ++y) {
      var uvOffset = y * uvRowStride;
      var yOffset = y * yRowStride;

      for (int x = 0; x < width; ++x) {
        nv21[idY++] = yBuffer[yOffset + x * yPixelStride];

        if (y < uvHeight && x < uvWidth) {
          var bufferIndex = uvOffset + (x * uvPixelStride);
          //V channel
          nv21[idUV++] = vBuffer[bufferIndex];
          //V channel
          nv21[idUV++] = uBuffer[bufferIndex];
        }
      }
    }
    return Uint8List.fromList(nv21);
  }
}

const _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

InputImage? cameraImageToInputImage(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) {
    return null;
  }
  final plane = image.planes.firstOrNull;
  if (plane == null) {
    return null;
  }

  final sensorOrientation = camera.sensorOrientation;

  final InputImageRotation? rotation;
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var rotationCompensation = _orientations[deviceOrientation];
    if (rotationCompensation == null) {
      return null;
    }
    if (camera.lensDirection == CameraLensDirection.front) {
      // front-facing
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // back-facing
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  } else {
    rotation = null;
  }

  if (rotation == null) {
    return null;
  }

  final Uint8List bytes;
  if (Platform.isAndroid) {
    bytes = image.getNv21Uint8List();
  } else {
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    bytes = allBytes.done().buffer.asUint8List();
  }

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation, // used only in Android
      format: Platform.isAndroid
          ? InputImageFormat.nv21
          : format, // Hardcode format for Android
      bytesPerRow: plane.bytesPerRow, // used only in iOS
    ),
  );
}
