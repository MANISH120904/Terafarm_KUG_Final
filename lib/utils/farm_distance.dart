import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../location.dart';

class FarmWithDistance {
  FarmWithDistance({required this.doc, required this.distanceKm});
  final DocumentSnapshot doc;
  final double distanceKm;
}

/// Filter farms within [radiusKm] of buyer position. Farms without coords excluded.
List<FarmWithDistance> farmsWithinRadius({
  required List<DocumentSnapshot> docs,
  required double radiusKm,
  Position? buyerPosition,
}) {
  final pos = buyerPosition ?? LocationService().currentPosition;
  if (pos == null) return const [];

  final out = <FarmWithDistance>[];
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) continue;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    final meters = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );
    final km = meters / 1000.0;
    if (km <= radiusKm) {
      out.add(FarmWithDistance(doc: doc, distanceKm: km));
    }
  }
  out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  return out;
}

String formatDistanceKm(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}
