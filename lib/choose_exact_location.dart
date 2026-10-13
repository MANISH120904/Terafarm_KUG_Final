import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ChooseExactLocationScreen extends StatefulWidget {
  const ChooseExactLocationScreen({Key? key}) : super(key: key);

  @override
  State<ChooseExactLocationScreen> createState() => _ChooseExactLocationScreenState();
}

class _ChooseExactLocationScreenState extends State<ChooseExactLocationScreen> {
  LatLng selectedLocation = LatLng(37.7749, -122.4194); // Default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Choose Exact Location"),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, selectedLocation);
            },
          )
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          center: selectedLocation,
          zoom: 13.0,
          onTap: (tapPosition, point) {
            setState(() {
              selectedLocation = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=YOUR_MAPBOX_ACCESS_TOKEN',
            additionalOptions: {
              'accessToken': 'pk.eyJ1Ijoibm90bWFkIiwiYSI6ImNtOWRvbmxxcTBjYmIybXNhMTZwaWR5YWEifQ.uq5aCi9NGmifjGtj-XlT_g',
            },
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: selectedLocation,
                child: const Icon(Icons.location_on, size: 40, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}