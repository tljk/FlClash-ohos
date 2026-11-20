import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holding/holding.dart';

enum HandSide { left, right }

class HoldingHandState extends ChangeNotifier {
  HoldingHandStatus? _holdingStatus;
  OperatingHandStatus? _operatingStatus;
  HandSide? _handSide;

  HoldingHandStatus? get holdingStatus => _holdingStatus;
  OperatingHandStatus? get operatingStatus => _operatingStatus;
  HandSide? get handSide => _handSide;

  void updateHoldingStatus(HoldingHandStatus status) {
    _holdingStatus = status;
    _updateHandSide(switch (status) {
      HoldingHandStatus.left => HandSide.left,
      HoldingHandStatus.right => HandSide.right,
      _ => null,
    });
  }

  void updateOperatingStatus(OperatingHandStatus status) {
    _operatingStatus = status;
    if (_holdingStatus == HoldingHandStatus.both) {
      return;
    }
    _updateHandSide(switch (status) {
      OperatingHandStatus.left => HandSide.left,
      OperatingHandStatus.right => HandSide.right,
      OperatingHandStatus.unknown => switch (_holdingStatus) {
        HoldingHandStatus.left => HandSide.left,
        HoldingHandStatus.right => HandSide.right,
        _ => null,
      },
    });
  }

  void _updateHandSide(HandSide? handSide) {
    if (handSide == null || handSide == _handSide) {
      return;
    }
    _handSide = handSide;
    notifyListeners();
  }
}

final holdingHandState = HoldingHandState();

class HoldingManager extends ConsumerStatefulWidget {
  final Widget child;

  const HoldingManager({super.key, required this.child});

  @override
  ConsumerState<HoldingManager> createState() => _HoldingManagerState();
}

class _HoldingManagerState extends ConsumerState<HoldingManager> {
  final Holding _holding = Holding();
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      appSettingProvider.select(
        (setting) => (setting.smartReach, setting.floatingNavigationBar),
      ),
      (_, _) => _updateSubscription(),
      fireImmediately: true,
    );
  }

  void _updateSubscription() {
    final setting = ref.read(appSettingProvider);
    final enabled = setting.smartReach && !setting.floatingNavigationBar;
    if (enabled == _isSubscribed) {
      return;
    }
    _isSubscribed = enabled;
    if (enabled) {
      _holding.subscribeHoldingHand(
        SubscribeHoldingHandOptions(
          onChange: (status) {
            if (mounted && _isSubscribed) {
              holdingHandState.updateHoldingStatus(status);
            }
          },
          fail: (message) {
            commonPrint.log(
              'Failed to subscribe to holding hand changes: $message',
              logLevel: LogLevel.error,
            );
          },
        ),
      );
      _holding.subscribeOperatingHand(
        SubscribeOperatingHandOptions(
          onChange: (status) {
            if (mounted && _isSubscribed) {
              holdingHandState.updateOperatingStatus(status);
            }
          },
          fail: (message) {
            commonPrint.log(
              'Failed to subscribe to operating hand changes: $message',
              logLevel: LogLevel.error,
            );
          },
        ),
      );
    } else {
      _holding.unsubscribeHoldingHand(
        UnsubscribeHoldingHandOptions(
          fail: (message) {
            commonPrint.log(
              'Failed to unsubscribe from holding hand changes: $message',
              logLevel: LogLevel.error,
            );
          },
        ),
      );
      _holding.unsubscribeOperatingHand(
        UnsubscribeOperatingHandOptions(
          fail: (message) {
            commonPrint.log(
              'Failed to unsubscribe from operating hand changes: $message',
              logLevel: LogLevel.error,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_isSubscribed) {
      _isSubscribed = false;
      _holding.unsubscribeHoldingHand(
        UnsubscribeHoldingHandOptions(
          fail: (message) {
            commonPrint.log(
              'Failed to unsubscribe from holding hand changes: $message',
              logLevel: LogLevel.error,
            );
          },
        ),
      );
      _holding.unsubscribeOperatingHand(
        UnsubscribeOperatingHandOptions(
          fail: (message) {
            commonPrint.log(
              'Failed to unsubscribe from operating hand changes: $message',
              logLevel: LogLevel.error,
            );
          },
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
