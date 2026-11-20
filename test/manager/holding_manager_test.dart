import 'package:fl_clash/manager/holding_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holding/holding.dart';

void main() {
  test('last left or right status from either stream wins', () {
    final state = HoldingHandState();
    addTearDown(state.dispose);

    state.updateHoldingStatus(HoldingHandStatus.left);
    expect(state.handSide, HandSide.left);

    state.updateOperatingStatus(OperatingHandStatus.right);
    expect(state.handSide, HandSide.right);

    state.updateHoldingStatus(HoldingHandStatus.right);
    expect(state.handSide, HandSide.right);

    state.updateOperatingStatus(OperatingHandStatus.left);
    expect(state.handSide, HandSide.left);
  });

  test(
    'non-positioning states are retained without changing the hand side',
    () {
      final state = HoldingHandState();
      addTearDown(state.dispose);

      state.updateHoldingStatus(HoldingHandStatus.left);
      state.updateHoldingStatus(HoldingHandStatus.none);
      state.updateOperatingStatus(OperatingHandStatus.unknown);

      expect(state.holdingStatus, HoldingHandStatus.none);
      expect(state.operatingStatus, OperatingHandStatus.unknown);
      expect(state.handSide, HandSide.left);
    },
  );

  test(
    'operating status update is ignored while both hands are holding the device',
    () {
      final state = HoldingHandState();
      addTearDown(state.dispose);

      state.updateHoldingStatus(HoldingHandStatus.both);
      state.updateOperatingStatus(OperatingHandStatus.right);

      expect(state.operatingStatus, OperatingHandStatus.right);
      expect(state.handSide, isNull);
    },
  );

  test(
    'unknown operating status falls back to a directional holding status',
    () {
      final state = HoldingHandState();
      addTearDown(state.dispose);

      state.updateOperatingStatus(OperatingHandStatus.right);
      state.updateHoldingStatus(HoldingHandStatus.left);
      state.updateOperatingStatus(OperatingHandStatus.unknown);

      expect(state.operatingStatus, OperatingHandStatus.unknown);
      expect(state.handSide, HandSide.left);
    },
  );
}
