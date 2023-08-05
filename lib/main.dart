import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CameraApp(),
    );
  }
}


// 메인 화면(카메라로 촬영)
class CameraApp extends StatefulWidget {

  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  late Timer _timer;
  bool isScanning = true;
  List<Image> icons = [Image.asset("assets/images/pause.png"), Image.asset("assets/images/play.png")];
  int curIcon = 0;
  String scanResult = "Not Found";
  String temp = "Scanning...";
  double x = 0;
  double y = 0;

  // 시작시 상태 초기화
  @override
  void initState() {
    super.initState();
    // 카메라 시작
    initCamera();
    // 타이머 작동
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      captureAndUpload();
    });
  }

  // 카메라 시작
  Future<void> initCamera() async {
    controller = CameraController(_cameras[0], ResolutionPreset.max);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
  }

  // 촬영 및 업로드
  Future<void> captureAndUpload() async {
    if (controller.value.isInitialized) {
      // 촬영
      controller.setFocusMode(FocusMode.locked);
      final XFile image = await controller.takePicture();
      controller.setFocusMode(FocusMode.auto);
      // 업로드
      uploadImage(File(image.path));
    }
  }

  // 업로드
  Future<void> uploadImage(File imageFile) async {
    // 주소
    final uri = Uri.parse('http://121.137.148.133:5000/test');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    print("Image sent");
    var response = await request.send();
    temp = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      print("Image scanned successfully!");
      setState(() {
        scanResult = temp;
      });
    } else {
      print("#${response.statusCode} Error");
      scanResult = "Invalid Image";
    }
  }

  @override
  void dispose() {
    controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  // 타이머 정지
  void pause() {
    _timer.cancel();
  }

  // 타이머 작동
  void restart() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      captureAndUpload();
    });
  }


  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
        body: Center(
          child: Column(
            children: [
              const SizedBox(height: 35),
              Expanded(
                flex: 20,
                  child: CameraPreview(
                    controller,
                    child: GestureDetector(onTapDown: (TapDownDetails details) {
                      x = details.localPosition.dx;
                      y = details.localPosition.dy;

                      double fullWidth = MediaQuery.of(context).size.width;
                      double cameraHeight = fullWidth * controller.value.aspectRatio;

                      double xp = x / fullWidth;
                      double yp = y / cameraHeight;

                      Offset point = Offset(xp,yp);
                      controller.setFocusPoint(point);
                    },),
                  )
              ),
              Expanded(flex:2, child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(scanResult, style: const TextStyle(fontSize: 40),),
              )),
              Expanded(
                flex:3,
                child: IconButton(
                icon: icons[curIcon],
                onPressed: (){
                  if (isScanning) {
                    isScanning = !isScanning;
                    setState(() {
                      curIcon = (curIcon+1)%2;
                    });
                    pause();
                  } else {
                    isScanning = !isScanning;
                    restart();
                    setState(() {
                      curIcon = (curIcon+1)%2;
                    });
                  }
                },
              )
              )
            ],
          ),
        )
    );
  }
}