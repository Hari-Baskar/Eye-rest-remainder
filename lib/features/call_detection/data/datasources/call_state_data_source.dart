import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/call_state_entity.dart';

/// CallStateDataSource
///
/// Communicates with native Android platform channels to receive
/// real-time updates regarding call states (`TelephonyManager`)
/// and proximity sensor events (phone near/away from ear).
class CallStateDataSource {
  static const MethodChannel _methodChannel = MethodChannel('com.reset/call_proximity');
  static const EventChannel _eventChannel = EventChannel('com.reset/call_proximity_events');

  StreamController<CallStateEntity>? _controller;
  StreamSubscription? _nativeSubscription;
  CallStateEntity _currentState = CallStateEntity.initial();

  /// Starts listening to native call state and proximity events
  Stream<CallStateEntity> get callStateStream {
    _controller ??= StreamController<CallStateEntity>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _controller!.stream;
  }

  /// Queries the current call, proximity, and media playback state directly
  Future<CallStateEntity> checkCurrentState() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _methodChannel.invokeMethod('getCallProximityState');
      if (result != null) {
        _currentState = CallStateEntity(
          isInCall: result['isInCall'] as bool? ?? false,
          isProximityNear: result['isProximityNear'] as bool? ?? false,
          isScreenInteractive: result['isScreenInteractive'] as bool? ?? true,
          isMediaPlaying: result['isMediaPlaying'] as bool? ?? false,
        );
      }
    } catch (_) {
      // Platform channel fallback if not available on current device/OS
    }
    return _currentState;
  }

  /// Queries whether media/movie audio is playing
  Future<bool> checkIsMediaPlaying() async {
    try {
      final bool? isPlaying = await _methodChannel.invokeMethod<bool>('isMediaPlaying');
      return isPlaying ?? false;
    } catch (_) {
      return false;
    }
  }

  void _startListening() {
    try {
      _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            _currentState = CallStateEntity(
              isInCall: event['isInCall'] as bool? ?? false,
              isProximityNear: event['isProximityNear'] as bool? ?? false,
              isScreenInteractive: event['isScreenInteractive'] as bool? ?? true,
              isMediaPlaying: event['isMediaPlaying'] as bool? ?? false,
            );
            _controller?.add(_currentState);
          }
        },
        onError: (_) {
          // Graceful fallback for non-supported platforms
        },
      );
    } catch (_) {}
  }

  void _stopListening() {
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
  }

  /// Disposes controller resources
  void dispose() {
    _stopListening();
    _controller?.close();
    _controller = null;
  }
}
