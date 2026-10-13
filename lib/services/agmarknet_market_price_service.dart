import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import 'local_market_price_service.dart';

/// Live mandi prices from data.gov.in (Agmarknet) — no Render backend.
///
/// Resource: Current Daily Price of Various Commodities from Various Markets
/// https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070
class AgmarknetMarketPriceService {
  static const _resourceId = '9ef84268-d588-465a-a308-a864a43d0070';
  static const _baseHost = 'api.data.gov.in';

  /// Public sample key from data.gov.in docs (max ~10 records). Prefer
  /// `AGMARKNET_API_KEY` in dart_defines.json for fuller access.
  static const _sampleKey =
      '579b464db66ec23bdd000001cdd3946e44ce4aad7209ff7b23ac571b';

  static String get _apiKey =>
      ApiKeys.hasAgmarknet ? ApiKeys.agmarknet : _sampleKey;

  static Uri _uri(Map<String, String> query) {
    return Uri.https(
      _baseHost,
      '/resource/$_resourceId',
      {
        'api-key': _apiKey,
        'format': 'json',
        ...query,
      },
    );
  }

  /// Unique commodity names for a state (from recent mandi rows).
  static Future<List<String>> commoditiesForState(String state) async {
    try {
      final uri = _uri({
        'limit': '100',
        'offset': '0',
        'filters[state.keyword]': state,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return LocalMarketPriceService.commoditiesForState(state);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final records = (body['records'] as List?) ?? [];
      final names = <String>{};
      for (final raw in records) {
        final r = raw as Map<String, dynamic>;
        final c = (r['commodity'] ?? '').toString().trim();
        if (c.isNotEmpty) names.add(c);
      }
      if (names.isEmpty) {
        return LocalMarketPriceService.commoditiesForState(state);
      }
      final list = names.toList()..sort();
      return list;
    } catch (_) {
      return LocalMarketPriceService.commoditiesForState(state);
    }
  }

  /// Mandi rows for state + commodity. Falls back to local demo prices.
  static Future<AgmarknetFetchResult> pricesFor({
    required String state,
    required String commodity,
  }) async {
    try {
      final uri = _uri({
        'limit': '50',
        'offset': '0',
        'filters[state.keyword]': state,
        'filters[commodity]': commodity,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return AgmarknetFetchResult.fallback(
          LocalMarketPriceService.pricesFor(state: state, commodity: commodity),
          'Agmarknet HTTP ${res.statusCode}; showing demo prices.',
        );
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final records = (body['records'] as List?) ?? [];
      if (records.isEmpty) {
        return AgmarknetFetchResult.fallback(
          LocalMarketPriceService.pricesFor(state: state, commodity: commodity),
          'No live mandi rows; showing demo prices.',
        );
      }

      final mapped = records.map((raw) {
        final r = raw as Map<String, dynamic>;
        return <String, dynamic>{
          'state': r['state']?.toString() ?? state,
          'district': r['district']?.toString() ?? '',
          'market': r['market']?.toString() ?? 'Market',
          'commodity': r['commodity']?.toString() ?? commodity,
          'variety': r['variety']?.toString() ?? '',
          'grade': r['grade']?.toString() ?? '',
          'arrival_date': r['arrival_date']?.toString() ?? '',
          'min_price': '${r['min_price'] ?? ''}',
          'max_price': '${r['max_price'] ?? ''}',
          'modal_price': '${r['modal_price'] ?? ''}',
        };
      }).toList();

      return AgmarknetFetchResult.live(mapped);
    } catch (e) {
      return AgmarknetFetchResult.fallback(
        LocalMarketPriceService.pricesFor(state: state, commodity: commodity),
        'Agmarknet unavailable; showing demo prices.',
      );
    }
  }
}

class AgmarknetFetchResult {
  final List<Map<String, dynamic>> rows;
  final bool isLive;
  final String? note;

  const AgmarknetFetchResult._({
    required this.rows,
    required this.isLive,
    this.note,
  });

  factory AgmarknetFetchResult.live(List<Map<String, dynamic>> rows) =>
      AgmarknetFetchResult._(rows: rows, isLive: true);

  factory AgmarknetFetchResult.fallback(
    List<Map<String, dynamic>> rows,
    String note,
  ) =>
      AgmarknetFetchResult._(rows: rows, isLive: false, note: note);
}
