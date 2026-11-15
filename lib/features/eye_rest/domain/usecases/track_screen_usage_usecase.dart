import '../entities/eye_rest_entity.dart';

/// TrackScreenUsageUseCase
///
/// Business logic use case that handles continuous screen-on duration calculation,
/// total daily screen time accumulation, automatic eye break detection after 20+s rest/inactivity,
/// and manual break triggering.
class TrackScreenUsageUseCase {
  /// Minimum duration of inactivity/stepping away in seconds to qualify as an eye break (20 seconds).
  static const int kMinBreakInactivitySeconds = 20;

  /// Minimum continuous screen usage before an eye break can be automatically awarded (20 seconds).
  static const int kMinSessionForAutoBreakSeconds = 20;

  /// Updates continuous session duration and cumulative daily screen time when screen is active.
  EyeRestEntity onScreenTick(EyeRestEntity currentEntity, int secondsElapsed, {bool isInCall = false}) {
    if (!currentEntity.isEnabled || isInCall) {
      return currentEntity;
    }
    return currentEntity.copyWith(
      currentScreenSeconds: currentEntity.currentScreenSeconds + secondsElapsed,
      totalDailyScreenSeconds: currentEntity.totalDailyScreenSeconds + secondsElapsed,
    );
  }

  /// Handles when screen is turned off / locked.
  EyeRestEntity onScreenLocked(EyeRestEntity currentEntity) {
    return currentEntity.copyWith(
      lastLockedTime: DateTime.now(),
    );
  }

  /// Handles when screen is turned back on / unlocked.
  /// If phone was away/locked for 20+ seconds after screen usage, awards an eye break!
  EyeRestEntity onScreenUnlocked(EyeRestEntity currentEntity) {
    final lastLocked = currentEntity.lastLockedTime;
    if (lastLocked == null) {
      return currentEntity;
    }

    final diffSeconds = DateTime.now().difference(lastLocked).inSeconds;
    if (diffSeconds >= kMinBreakInactivitySeconds &&
        currentEntity.currentScreenSeconds >= kMinSessionForAutoBreakSeconds) {
      // User took a real rest break (20s+): award break counter and reset continuous timer
      return currentEntity.copyWith(
        breaksTakenToday: currentEntity.breaksTakenToday + 1,
        currentScreenSeconds: 0,
        sessionStartTime: DateTime.now(),
        lastLockedTime: null,
      );
    } else if (diffSeconds >= kMinBreakInactivitySeconds) {
      return currentEntity.copyWith(
        currentScreenSeconds: 0,
        sessionStartTime: DateTime.now(),
        lastLockedTime: null,
      );
    } else {
      // Short reopen: maintain continuous session
      return currentEntity.copyWith(
        lastLockedTime: null,
      );
    }
  }

  /// Evaluates continuous inactivity (resting untouched on table/sofa/inactivity for 20+s).
  /// Automatically counts as an eye break if user was previously using screen for >= 20s.
  EyeRestEntity onInactivity(EyeRestEntity currentEntity, int idleSeconds) {
    if (idleSeconds >= kMinBreakInactivitySeconds &&
        currentEntity.currentScreenSeconds >= kMinSessionForAutoBreakSeconds) {
      return currentEntity.copyWith(
        breaksTakenToday: currentEntity.breaksTakenToday + 1,
        currentScreenSeconds: 0,
        sessionStartTime: DateTime.now(),
      );
    } else if (idleSeconds >= kMinBreakInactivitySeconds && currentEntity.currentScreenSeconds > 0) {
      return currentEntity.copyWith(
        currentScreenSeconds: 0,
        sessionStartTime: DateTime.now(),
      );
    }
    return currentEntity;
  }

  /// Manually or automatically records an eye break and resets the continuous session timer.
  EyeRestEntity recordBreak(EyeRestEntity currentEntity) {
    return currentEntity.copyWith(
      breaksTakenToday: currentEntity.breaksTakenToday + 1,
      currentScreenSeconds: 0,
      sessionStartTime: DateTime.now(),
      lastLockedTime: null,
    );
  }

  /// Resets the continuous session timer.
  EyeRestEntity resetSession(EyeRestEntity currentEntity) {
    return currentEntity.copyWith(
      currentScreenSeconds: 0,
      sessionStartTime: DateTime.now(),
      lastLockedTime: null,
    );
  }
}
