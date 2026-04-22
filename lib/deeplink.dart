library deeplink;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeeplinkConfig {
  final String apiUrl;
  final String sdkKey;
  final String? appVersion;

  DeeplinkConfig({required String apiUrl, required this.sdkKey, this.appVersion})
      : apiUrl = apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
}

class DeviceInfo {
  final String platform;
  final String? osVersion;
  final String? model;
  final String? screen;
  final String? locale;
  final String? timezone;
  final String? appVersion;

  DeviceInfo({
    required this.platform,
    this.osVersion,
    this.model,
    this.screen,
    this.locale,
    this.timezone,
    this.appVersion,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'platform': platform};
    if (osVersion != null) m['osVersion'] = osVersion;
    if (model != null) m['model'] = model;
    if (screen != null) m['screen'] = screen;
    if (locale != null) m['locale'] = locale;
    if (timezone != null) m['timezone'] = timezone;
    if (appVersion != null) m['appVersion'] = appVersion;
    return m;
  }
}

class ResolvedLink {
  final String? id;
  final String? slug;
  final String? target;
  final Map<String, dynamic>? params;
  ResolvedLink({this.id, this.slug, this.target, this.params});
}

class ResolveResult {
  final bool matched;
  final ResolvedLink? link;
  ResolveResult({required this.matched, this.link});
}

class Deeplink {
  static DeeplinkConfig? _config;
  static final _http = http.Client();

  static void configure(DeeplinkConfig config) { _config = config; }

  static DeeplinkConfig _require() {
    final c = _config;
    if (c == null) throw StateError('Deeplink not configured — call Deeplink.configure() first');
    return c;
  }

  static Future<DeviceInfo> collectDevice() async {
    final cfg = _require();
    final plugin = DeviceInfoPlugin();
    String platform = 'unknown', osVersion = '', model = '';
    String appVersion = cfg.appVersion ?? '';
    if (appVersion.isEmpty) {
      try { appVersion = (await PackageInfo.fromPlatform()).version; } catch (_) {}
    }
    try {
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        platform = 'ios';
        osVersion = i.systemVersion;
        model = i.utsname.machine;
      } else if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        platform = 'android';
        osVersion = a.version.release;
        model = '${a.manufacturer} ${a.model}';
      }
    } catch (_) {}
    return DeviceInfo(
      platform: platform,
      osVersion: osVersion.isEmpty ? null : osVersion,
      model: model.isEmpty ? null : model,
      locale: Intl.getCurrentLocale(),
      timezone: DateTime.now().timeZoneName,
      appVersion: appVersion.isEmpty ? null : appVersion,
    );
  }

  /// Call on first app open. Resolves deferred deep link and records install.
  static Future<ResolveResult> handleFirstLaunch() async {
    final device = await collectDevice();
    // fire-and-forget install
    unawaited(recordInstall(device: device).catchError((_) {}));
    return resolve(device: device);
  }

  static Future<ResolveResult> resolve({DeviceInfo? device}) async {
    device ??= await collectDevice();
    final data = await _post('/v1/sdk/resolve', {'device': device.toJson()});
    final root = (data['data'] ?? {}) as Map<String, dynamic>;
    final matched = (root['matched'] ?? false) as bool;
    final linkMap = root['link'] as Map<String, dynamic>?;
    return ResolveResult(
      matched: matched,
      link: linkMap == null ? null : ResolvedLink(
        id: linkMap['id'] as String?,
        slug: linkMap['slug'] as String?,
        target: linkMap['target'] as String?,
        params: (linkMap['params'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  static Future<void> recordInstall({DeviceInfo? device}) async {
    device ??= await collectDevice();
    await _post('/v1/sdk/install', {'device': device.toJson()});
  }

  static Future<void> recordOpen({DeviceInfo? device, String? linkId}) async {
    device ??= await collectDevice();
    final body = <String, dynamic>{'device': device.toJson()};
    if (linkId != null) body['linkId'] = linkId;
    await _post('/v1/sdk/open', body);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final cfg = _require();
    final res = await _http.post(
      Uri.parse(cfg.apiUrl + path),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${cfg.sdkKey}',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Deeplink ${path} failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
