import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opencv_test/main_notifier.dart';

final myNotifierProvider = ChangeNotifierProvider<MyNotifier>((ref) {
  return MyNotifier();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: CameraApp()));
}

/// CameraApp is the Main Application.
class CameraApp extends StatelessWidget {
  /// Default Constructor
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, child) {
          MyNotifier myNotifier = ref.watch(myNotifierProvider);

          return myNotifier.cameraIsInitialized
              ? myNotifier.showProcessedPreview
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.memory(myNotifier.imageData),
                        MaterialButton(
                          onPressed: () {
                            myNotifier.getImage();
                          },
                          child: Text('get image'),
                        ),
                        MaterialButton(
                          onPressed: () {
                            myNotifier.getImage2();
                          },
                          child: Text('get image2'),
                        )
                      ],
                    ))
                  : Stack(
                      children: [
                        CameraPreview(myNotifier.cameraController),
                        if (myNotifier.faceResult != null)
                          Positioned(
                            left: myNotifier.faceResult?.bboxTopLeft.$1,
                            top: myNotifier.faceResult?.bboxTopLeft.$2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(
                                  color: Colors.greenAccent,
                                  width: 2,
                                ),
                              ),
                              width: myNotifier.faceResult?.bboxSize.$1,
                              height: myNotifier.faceResult?.bboxSize.$2,
                              child: Text(
                                'score: ${myNotifier.faceResult?.faceScore.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            children: [
                              Text(
                                'right eye closed: ${myNotifier.faceResult?.leftEye.toString()}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'left eye closed: ${myNotifier.faceResult?.rightEye.toString()}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
              : const Text('camera not init');
        }),
      ),
    );
  }
}
