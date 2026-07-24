import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('AppSetting provider', () {
    test('default value is defaultAppSettingProps', () {
      final value = container.read(appSettingProvider);
      expect(value.onlyStatisticsProxy, false);
      expect(value.autoLaunch, false);
      expect(value.closeConnections, true);
      expect(value.isAnimateToPage, true);
    });

    test('can update state', () {
      container.read(appSettingProvider.notifier).update(
            (_) => const AppSettingProps(autoLaunch: true),
          );
      final value = container.read(appSettingProvider);
      expect(value.autoLaunch, true);
    });
  });

  group('WindowSetting provider', () {
    test('default value has zero dimensions', () {
      final value = container.read(windowSettingProvider);
      expect(value.width, 0);
      expect(value.height, 0);
    });

    test('can update state', () {
      container.read(windowSettingProvider.notifier).update(
            (_) => const WindowProps(width: 1024, height: 768),
          );
      final value = container.read(windowSettingProvider);
      expect(value.width, 1024);
      expect(value.height, 768);
    });
  });

  group('VpnSetting provider', () {
    test('default value has enable true', () {
      final value = container.read(vpnSettingProvider);
      expect(value.enable, true);
      expect(value.systemProxy, true);
    });

    test('can update state', () {
      container.read(vpnSettingProvider.notifier).update(
            (_) => const VpnProps(enable: false),
          );
      expect(container.read(vpnSettingProvider).enable, false);
    });
  });

  group('NetworkSetting provider', () {
    test('default values', () {
      final value = container.read(networkSettingProvider);
      expect(value.systemProxy, true);
      expect(value.bypassDomain, defaultBypassDomain);
    });

    test('can update state', () {
      container.read(networkSettingProvider.notifier).update(
            (_) => const NetworkProps(systemProxy: false),
          );
      expect(container.read(networkSettingProvider).systemProxy, false);
    });
  });

  group('ThemeSetting provider', () {
    test('default value is dark mode', () {
      final value = container.read(themeSettingProvider);
      expect(value.primaryColor, null);
    });

    test('can update state', () {
      container.read(themeSettingProvider.notifier).update(
            (_) => const ThemeProps(primaryColor: 0xFF123456),
          );
      expect(
        container.read(themeSettingProvider).primaryColor,
        0xFF123456,
      );
    });
  });

  group('CurrentProfileId provider', () {
    test('default is null', () {
      expect(container.read(currentProfileIdProvider), null);
    });

    test('can set profile id', () {
      container.read(currentProfileIdProvider.notifier).update((_) => 42);
      expect(container.read(currentProfileIdProvider), 42);
    });
  });

  group('DavSetting provider', () {
    test('default is null', () {
      expect(container.read(davSettingProvider), null);
    });
  });

  group('OverrideDns provider', () {
    test('default is false', () {
      expect(container.read(overrideDnsProvider), false);
    });

    test('can toggle on', () {
      container.read(overrideDnsProvider.notifier).update((_) => true);
      expect(container.read(overrideDnsProvider), true);
    });
  });

  group('HotKeyActions provider', () {
    test('default is empty list', () {
      expect(container.read(hotKeyActionsProvider), isEmpty);
    });
  });

  group('ProxiesStyleSetting provider', () {
    test('default values', () {
      final value = container.read(proxiesStyleSettingProvider);
      expect(value.type, ProxiesType.tab);
    });

    test('can update state', () {
      container.read(proxiesStyleSettingProvider.notifier).update(
            (_) => const ProxiesStyleProps(sortType: ProxiesSortType.delay),
          );
      expect(
        container.read(proxiesStyleSettingProvider).sortType,
        ProxiesSortType.delay,
      );
    });
  });

  group('configProvider (composite)', () {
    test('composes all sub-providers with defaults', () {
      final config = container.read(configProvider);
      expect(config.appSettingProps.onlyStatisticsProxy, false);
      expect(config.windowProps.width, 0);
      expect(config.vpnProps.enable, true);
      expect(config.networkProps.systemProxy, true);
      expect(config.currentProfileId, null);
      expect(config.overrideDns, false);
      expect(config.hotKeyActions, isEmpty);
    });

    test('reflects updated sub-provider values', () {
      container.read(currentProfileIdProvider.notifier).update((_) => 99);
      container.read(overrideDnsProvider.notifier).update((_) => true);

      final config = container.read(configProvider);
      expect(config.currentProfileId, 99);
      expect(config.overrideDns, true);
    });
  });

  group('buildConfigOverrides', () {
    test('produces correct overrides', () {
      const config = Config(
        themeProps: ThemeProps(),
        currentProfileId: 7,
        overrideDns: true,
      );
      final overrides = buildConfigOverrides(config);
      expect(overrides.length, 13);

      final overrideContainer = ProviderContainer(overrides: overrides);
      addTearDown(overrideContainer.dispose);

      expect(overrideContainer.read(currentProfileIdProvider), 7);
      expect(overrideContainer.read(overrideDnsProvider), true);
      expect(
        overrideContainer.read(appSettingProvider).onlyStatisticsProxy,
        false,
      );
    });
  });
}
