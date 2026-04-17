
class AudioSample {
  final String source;
  final String language;
  final String sampleName;
  final List<dynamic> extractedFeatures; 
  final String audioFilePath;

  AudioSample({
    required this.source,
    required this.language,
    required this.sampleName,
    required this.extractedFeatures,
    required this.audioFilePath,
  });

  factory AudioSample.fromJson(Map<String, dynamic> json) {
    return AudioSample(
      source: json['source'] ?? 'Unknown Source',
      language: json['language'] ?? 'Unknown Language',
      sampleName: json['name'] ?? 'Untitled Sample',
      extractedFeatures: json['features'] ?? [],
      audioFilePath: json['audio_path'] ?? '',
    );
  }
 
}