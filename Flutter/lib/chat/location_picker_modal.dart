import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerModal extends StatefulWidget {
  final Function(String name, String address, double lat, double lng)
  onLocationPicked;

  const LocationPickerModal({super.key, required this.onLocationPicked});

  @override
  _LocationPickerModalState createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _selectedName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check service status
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Option to warn user or ask to enable
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Location services are disabled. Please enable GPS.',
              ),
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Check permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied. Please enable in settings.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Get position
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _mapController.move(_selectedLocation!, 15.0);
          _getAddressFromLatLng(_selectedLocation!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedAddress =
              '${place.street}, ${place.locality}, ${place.country}';
          _selectedName = place.name ?? 'Selected Location';
        });
      } else {
        setState(() {
          _selectedAddress =
              'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          _selectedName = 'Pinned Location';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      // Set fallback on error too
      setState(() {
        _selectedAddress =
            'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
        _selectedName = 'Pinned Location';
      });
    }
  }

  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _selectedLocation = latlng;
      _getAddressFromLatLng(latlng);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          AppBar(
            title: const Text('Pick Meeting Location'),
            actions: [
              if (_selectedLocation != null)
                TextButton(
                  onPressed: () {
                    if (_selectedLocation != null) {
                      widget.onLocationPicked(
                        _selectedName ?? 'Pinned Location',
                        _selectedAddress ??
                            '${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}',
                        _selectedLocation!.latitude,
                        _selectedLocation!.longitude,
                      );
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a location on the map'),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Confirm',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _selectedLocation ?? LatLng(0, 0),
                      zoom: 15,
                      onTap: _handleTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.project',
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: _selectedLocation!,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          if (_selectedAddress != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _selectedAddress!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        ],
      ),
    );
  }
}
