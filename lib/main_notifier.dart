import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opencv_dart/opencv.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:opencv_test/models/face_result.dart';
import 'package:path_provider/path_provider.dart';

class MyNotifier extends ChangeNotifier {
  MyNotifier() {
    print('init only once');
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
    final _model =
        await rootBundle.load('assets/face_detection_yunet_2023mar.onnx');

    _modelBuffer = _model.buffer.asUint8List();
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
      imageFormatGroup: ImageFormatGroup.jpeg,
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

  FaceResult? _faceResult;
  FaceResult? get faceResult => _faceResult;

  Future<void> _getImageData() async {
    await _cameraController.startImageStream((image) async {
      Mat mat = await convertCameraImageToMat(image);
      mat = cv.rotate(mat, cv.ROTATE_90_COUNTERCLOCKWISE);
      mat = cv.resize(mat, (320, 320));

      if (mat.data.isEmpty) {
        print('nothing');
        return;
      }

      _faceResult = detectFace(mat);
      // _imageData = imencode('.jpeg', mat).$2;

      notifyListeners();
    });
  }

  void printMat(cv.Mat mat) {
    if (mat.cols > 0) {
      print('score: ${mat.atPixel(0, 14)}');
    }
  }

  FaceResult? detectFace(Mat mat) {
    if (!_modelLoaded) {
      print('MODEL NOT READY!!!!!');
      return null;
    }
    faceDetectorYN ??= cv.FaceDetectorYN.fromBuffer(
      "onnx",
      _modelBuffer,
      Uint8List(0),
      (320, 320),
    );

    Mat? result = faceDetectorYN?.detect(mat);
    if (result == null) {
      return null;
    }

    FaceResult? resultModel = FaceResult.getModel(result);
    return resultModel;
  }

  Future<cv.Mat> convertCameraImageToMat(CameraImage cameraImage) async {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      try {
        // Assuming cameraImage.planes[0] is Y, planes[1] is U, and planes[2] is V.
        Uint8List yBytes = cameraImage.planes[0].bytes;
        Uint8List uBytes = cameraImage.planes[1].bytes;
        Uint8List vBytes = cameraImage.planes[2].bytes;

        int width = cameraImage.width;
        int height = cameraImage.height;

        cv.Mat yMat =
            cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, yBytes);
        cv.Mat uMat = cv.Mat.fromList(
            height ~/ 2, width ~/ 2, cv.MatType.CV_8UC1, uBytes);
        cv.Mat vMat = cv.Mat.fromList(
            height ~/ 2, width ~/ 2, cv.MatType.CV_8UC1, vBytes);

        // Resize U and V to match Y's dimensions.
        uMat = cv.resize(uMat, (width, height), interpolation: cv.INTER_LINEAR);
        vMat = cv.resize(vMat, (width, height), interpolation: cv.INTER_LINEAR);

        // Create a multi-channel YUV Mat using merge.
        cv.Mat yuvMat = cv.Mat.create(
            rows: height,
            cols: width,
            type: cv.MatType.CV_8UC3); // Corrected line

        cv.merge(VecMat.fromList([yMat, uMat, vMat]), dst: yuvMat);

        // Convert YUV to BGR.
        cv.Mat bgrMat = cv.Mat.create(
            rows: height,
            cols: width,
            type: cv.MatType.CV_8UC3); // Corrected line

        cv.cvtColor(
          yuvMat,
          cv.COLOR_YUV2RGB,
          dst: bgrMat,
        );

        return bgrMat;
      } catch (e) {
        print('Error converting YUV to Mat: $e');
        rethrow;
      }
    } else {
      print('Image format is not YUV420');
      throw Exception('Image format is not YUV420');
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
