import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'banner_spec.dart';

/// Single source of truth for the active banner.
/// Uses a keyed stack so overlapping route transitions can't leave a
/// stale banner behind (last-in during a transition isn't necessarily
/// last-out).
class BannerController extends ChangeNotifier {
  final Map<Object, BannerSpec> _entries = {};

  BannerSpec? get current {
    if (_entries.isEmpty) return null;
    return _entries.values.reduce((a, b) => b.priority > a.priority ? b : a);
  }

  void publish(Object owner, BannerSpec spec) {
    _entries[owner] = spec;
    _safeNotify();
  }

  void retract(Object owner) {
    if (_entries.remove(owner) != null) _safeNotify();
  }

  bool _notifyScheduled = false;

  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
