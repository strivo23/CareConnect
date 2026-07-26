import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioRecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordDuration = 0; // in seconds
  Timer? _timer;
  String? _recordedFilePath;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  int get recordDuration => _recordDuration;
  String? get recordedFilePath => _recordedFilePath;

  // Stream controllers for UI updates
  final StreamController<int> _durationController = StreamController<int>.broadcast();
  final StreamController<bool> _recordingStateController = StreamController<bool>.broadcast();
  final StreamController<bool> _playingStateController = StreamController<bool>.broadcast();

  Stream<int> get durationStream => _durationController.stream;
  Stream<bool> get recordingStateStream => _recordingStateController.stream;
  Stream<bool> get playingStateStream => _playingStateController.stream;

  AudioRecordingService() {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _playingStateController.add(false);
    });
  }

  /// Request microphone permission and check availability.
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking mic permission: $e');
      return false;
    }
  }

  /// Start recording audio up to 60 seconds maximum.
  Future<bool> startRecording({VoidCallback? onMaxDurationReached}) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/sos_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        _recordedFilePath = path;
        _isRecording = true;
        _recordDuration = 0;
        _recordingStateController.add(true);
        _durationController.add(0);

        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) async {
          _recordDuration++;
          _durationController.add(_recordDuration);

          if (_recordDuration >= 60) {
            await stopRecording();
            if (onMaxDurationReached != null) {
              onMaxDurationReached();
            }
          }
        });

        return true;
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
    return false;
  }

  /// Stop audio recording and return file path.
  Future<String?> stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _audioRecorder.stop();
      _isRecording = false;
      _recordingStateController.add(false);
      if (path != null) {
        _recordedFilePath = path;
      }
      return _recordedFilePath;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      _recordingStateController.add(false);
      return null;
    }
  }

  /// Play/Pause recorded voice message preview.
  Future<void> togglePlayPreview() async {
    if (_recordedFilePath == null || !File(_recordedFilePath!).existsSync()) {
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
      _isPlaying = false;
      _playingStateController.add(false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      _isPlaying = true;
      _playingStateController.add(true);
    }
  }

  /// Delete current recording and reset states.
  Future<void> deleteRecording() async {
    try {
      _timer?.cancel();
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
        _recordingStateController.add(false);
      }
      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
        _playingStateController.add(false);
      }
      if (_recordedFilePath != null) {
        final file = File(_recordedFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _recordedFilePath = null;
      _recordDuration = 0;
      _durationController.add(0);
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _durationController.close();
    _recordingStateController.close();
    _playingStateController.close();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }
}
