import 'package:opencv_dart/opencv_dart.dart';

class FaceResult {
  FaceResult._({
    required this.bboxTopLeft,
    required this.bboxSize,
    required this.rightEye,
    required this.leftEye,
    required this.noseTip,
    required this.rightMouthCorner,
    required this.leftMouthCorner,
    required this.faceScore,
  });
  /* 
  0-1: x, y of bbox top left corner
  2-3: width, height of bbox
  4-5: x, y of right eye (blue point in the example image)
  6-7: x, y of left eye (red point in the example image)
  8-9: x, y of nose tip (green point in the example image)
  10-11: x, y of right corner of mouth (pink point in the example image)
  12-13: x, y of left corner of mouth (yellow point in the example image)
  14: face score
  */

  final (double, double) bboxTopLeft;
  final (double, double) bboxSize;
  final (double, double) rightEye;
  final (double, double) leftEye;
  final (double, double) noseTip;
  final (double, double) rightMouthCorner;
  final (double, double) leftMouthCorner;
  final double faceScore;

  static FaceResult? getModel(Mat mat) {
    List<List<num>> matrix = mat.toList();
    if (matrix.isEmpty) {
      return null;
    } else if (matrix[0].length < 15) {
      return null;
    }
    List<double> column = matrix[0].map((e) => e.toDouble()).toList();

    return FaceResult._(
      bboxTopLeft: (column[0], column[1]),
      bboxSize: (column[2], column[3]),
      rightEye: (column[4], column[5]),
      leftEye: (column[6], column[7]),
      noseTip: (column[8], column[9]),
      rightMouthCorner: (column[10], column[11]),
      leftMouthCorner: (column[12], column[13]),
      faceScore: column[14],
    );
  }

  @override
  String toString() {
    return 'FaceResult(bboxTopLeft: $bboxTopLeft, bboxSize: $bboxSize, rightEye: $rightEye, leftEye: $leftEye, noseTip: $noseTip, rightMouthCorner: $rightMouthCorner, leftMouthCorner: $leftMouthCorner, faceScore: $faceScore)';
  }
}
