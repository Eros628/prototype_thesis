
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:voice_detector_app/class.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: Colors.black,
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            side: WidgetStateProperty.all(BorderSide(color: Colors.black)),
            foregroundColor: WidgetStateProperty.all(Colors.black),
          )
        )
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  AudioSample? selectedSample;
  bool isSampleSelected = false;
  List<AudioSample> audioSamples = [];
  bool isLoading = true;
  bool isFake = false;
  bool isDetecting = false;
  bool hasDetectionResult = false;
  late PlayerController controller;


  double realScore = 0.0;
  double fakeScore = 0.0;

  List<double> safeWaveformData = [];

  @override
  void initState(){
    super.initState();
    controller = PlayerController();
    loadSampleFromJson();

    controller.onCompletion.listen((_) {
      controller.seekTo(0);
      setState(() {}); 
    });
  }

  @override
  void dispose(){
    controller.dispose();
    super.dispose();
  }


  Future<void> loadSampleFromJson()async{
    try {

      final String jsonString = await rootBundle.loadString('assets/my_features.json'); 
      final List<dynamic> data = jsonDecode(jsonString);

      setState(() {
        audioSamples = data.map((data) => AudioSample.fromJson(data)).toList();
        isLoading = false;
      });
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio samples: $e'))
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

   Future<String> copyAssetToCache(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = assetPath.split('/').last;
      final File tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return tempFile.path;
    } catch (e) {
      throw Exception("Failed to load audio file.");
    }
  }

  void showLoadingModal(BuildContext context){
    showModalBottomSheet(
      isDismissible: false,
      backgroundColor: Colors.grey[500],
      context: context, 
      builder: (BuildContext context){
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.20,
          child: Column(
            spacing: 20,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: LoadingAnimationWidget.stretchedDots(color: Colors.white, size: 50)),
              Text("Verifying...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
            ],
          )
        );
      }
      );
  }

  void showModal(BuildContext context){
    showModalBottomSheet(
      context: context, 
      builder: (BuildContext context){
        return isLoading ? Center(child: CircularProgressIndicator()): SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: CarouselSlider(
            options: CarouselOptions(height: 280, enlargeCenterPage: true),
            items: audioSamples.map((item) {
              return Builder(
                builder: (BuildContext context) {
                  return  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    margin: EdgeInsets.symmetric(horizontal: 5.0),
                    child: OutlinedButton(
                      style: ButtonStyle(
                        shape:  WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        elevation: WidgetStateProperty.all(5.0)

                      ),
                      onPressed: () async {


                        setState((){
                          selectedSample = item;
                          isSampleSelected = true;
                          hasDetectionResult = false;
                          safeWaveformData = safeWaveformData;                            
                        });

                         if(context.mounted){
                            Navigator.pop(context); 
                          }
                        String realFilePath = await copyAssetToCache(item.audioFilePath);
              
                        await controller.preparePlayer(
                          path: realFilePath, 
                          shouldExtractWaveform: false,
                        );

                        List<double> extracted = await controller.waveformExtraction.extractWaveformData(
                          path: realFilePath,
                          noOfSamples: 100,
                        );

                        setState((){
                          safeWaveformData = extracted;                            
                        });
                        controller.setFinishMode(finishMode: FinishMode.pause);
                       
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: Text(item.sampleName, textAlign: TextAlign.center,style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          Center(child: Image.asset("assets/images/sound.png", width: 170, height: 170)),
                          
                          Text('Source: ${item.source}', textAlign: TextAlign.start,style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),),
                          Text('Language: ${item.language}', textAlign: TextAlign.start, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),

                        ]
                      ),
                    ),
                  );
                });
            }).toList(), 
            ),
        );
      }
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column( 
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 50),
          if(!hasDetectionResult)
            Column(
              children: [
                Text("Verify Voice Aunthenticity", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Select an audio sample to instantly analyze \nits authenticity.", style: TextStyle(fontSize: 14 ),textAlign: TextAlign.center,)
              ]
            ),
          if(hasDetectionResult && isFake)
            Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("Synthetic Audio Detected!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("The audio sample is likely generated by AI.", style: TextStyle(fontSize: 14 ),textAlign: TextAlign.center,),
                Container(
                  width: 271,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black
                    ),
                  padding: EdgeInsets.all(5),
                  child: Center(child: Text("${(fakeScore * 100).toStringAsFixed(2)}% Confidence Score", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                )
              ]
            ),

          if(hasDetectionResult && !isFake)
            Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20,),
                Text("Authentic Audio Detected!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Acoustic analysis indicates naturally occurring vocal features. No significant anomalies detected.", style: TextStyle(fontSize: 14 ),textAlign: TextAlign.center,),
                
                Container(
                  width: 271,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black
                  ),
                  padding: EdgeInsets.all(5),
                  child: Center(child: Text("${(realScore * 100).toStringAsFixed(2)}% Confidence Score", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                )

              ]
            ),
          SizedBox(height: 50),
          if(!hasDetectionResult)
            Image.asset("assets/images/unknown_result.png"),
          
          if(hasDetectionResult && isFake)
           Image.asset("assets/images/Ai_result.png"), 
          
          if(hasDetectionResult && !isFake)
            Image.asset("assets/images/human_result.png"),
          Divider(
            thickness: 2.0,
            indent: 20.0,
            endIndent: 20.0,
            color: Colors.black,
          ),
         SizedBox(height: 20),
          Column(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                style: ButtonStyle(
                  fixedSize: WidgetStateProperty.all(Size(331, 52)),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
                onPressed: (){
                  showModal(context);
                }, 
                child: Row(
                  spacing: 20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text( isSampleSelected ? selectedSample!.sampleName :"Select Audio Sample", style: TextStyle(fontSize: 14),),
                    Image.asset("assets/images/folder.png", width: 25, height: 25)
                  ],
                )),
               if(isSampleSelected)
                OutlinedButton(
                    style: ButtonStyle(

                      fixedSize: WidgetStateProperty.all(Size(331, 52)),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  onPressed: () async{
                   if(controller.playerState == PlayerState.playing){
                    await controller.pausePlayer();
                   } else{
                    await controller.startPlayer();

                   }
                    setState(() {
                    });
  
                  }, 
                  child: controller.playerState == PlayerState.playing ? 
                      AudioFileWaveforms(
                        size: Size(200, 30), 
                        playerController: controller,
                        waveformType: WaveformType.long,
                        waveformData: safeWaveformData,
                        playerWaveStyle: PlayerWaveStyle(
                          fixedWaveColor: const Color.fromARGB(255, 84, 41, 133),
                          liveWaveColor: const Color.fromARGB(255, 4, 127, 241),
                          seekLineColor: Colors.black,

                          waveThickness: 2.0,
                          spacing: 4.0,
                        ))
                      :
                      Row(
                    spacing: 20,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Preview Audio Sample", style: TextStyle(fontSize: 14)),
                      
                      Image.asset("assets/images/play.png")
                    ],
                  ))
            ]
          ),
          SizedBox(height: 40),
          OutlinedButton(
            onPressed: () async{

              if(selectedSample == null){
                if(context.mounted){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select an audio sample first.'))
                  );
                }
                return;
              }

              showLoadingModal(context);
              
              await Future.delayed(Duration(seconds: 2));
              final interpreter = await Interpreter.fromAsset('assets/deepfake_model_float32.tflite');

              // 1. THE SHAPE FIX: Transforms [400, 60] into [1, 60, 400, 1]
              var inputData = [
                selectedSample!.extractedFeatures.map((row) {
                  return (row as List).map((val) => [(val as num).toDouble()]).toList();
                }).toList()
              ];

              var outputData = List.filled(1 * 2, 0.0).reshape([1, 2]);

              interpreter.run(inputData, outputData);

              // 2. THE PERCENTAGE FIX: Softmax Math
              double rawReal = outputData[0][0]; 
              double rawFake = outputData[0][1]; 

              double expReal = exp(rawReal);
              double expFake = exp(rawFake);
              double sumExp = expReal + expFake;

              double realProbability = expReal / sumExp;
              double fakeProbability = expFake / sumExp;

              setState(() {
                realScore = realProbability;
                fakeScore = fakeProbability;
                isFake = fakeScore > realScore;
                hasDetectionResult = true;
              });

              if (context.mounted) {
                Navigator.pop(context);
              }


            }, 
            style: ButtonStyle(
              fixedSize: WidgetStateProperty.all(Size(331, 52)),
              backgroundColor: WidgetStateProperty.all(const Color.fromARGB(255, 204, 203, 203)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            ),
            child: Text("Verify Authenticity", style: TextStyle(fontSize: 14, fontWeight:FontWeight.bold, color: Colors.black)))
        ],
      ),
    );
  }
}




