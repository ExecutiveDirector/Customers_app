// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';

// class ChangeLocationScreen extends StatefulWidget {
//   const ChangeLocationScreen({super.key});

//   @override
//   _ChangeLocationScreenState createState() => _ChangeLocationScreenState();
// }

// class _ChangeLocationScreenState extends State<ChangeLocationScreen> {
//   LatLng? _selectedLocation;
//   GoogleMapController? _mapController;
//   String _address = '';
//   String _detailedAddress = '';
//   MapType _mapType = MapType.normal;
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _getCurrentLocation();
//   }

//   Future<void> _getCurrentLocation() async {
//     setState(() => _isLoading = true);
//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         if (mounted) {
//           _showSnackBar('Please enable location services', Icons.location_off);
//         }
//         setState(() => _isLoading = false);
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           if (mounted) {
//             _showSnackBar('Location permission denied', Icons.error_outline);
//           }
//           setState(() => _isLoading = false);
//           return;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         if (mounted) {
//           _showSnackBar(
//               'Location permission permanently denied. Please enable in settings.',
//               Icons.warning);
//         }
//         setState(() => _isLoading = false);
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       if (mounted) {
//         setState(() {
//           _selectedLocation = LatLng(position.latitude, position.longitude);
//           _isLoading = false;
//         });
//         _updateAddress(_selectedLocation!);
//       }
//     } catch (e) {
//       if (mounted) {
//         _showSnackBar('Error getting location: $e', Icons.error);
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _updateAddress(LatLng position) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );
//       if (placemarks.isNotEmpty) {
//         final place = placemarks[0];
//         if (mounted) {
//           setState(() {
//             _address = '${place.street ?? 'Unknown Street'}';
//             _detailedAddress =
//                 '${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
//                     .replaceAll(RegExp(r'^,\s*|,\s*,'), '');
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint('Error getting address: $e');
//       if (mounted) {
//         setState(() {
//           _address = 'Unable to load address';
//           _detailedAddress = '';
//         });
//       }
//     }
//   }

//   void _onMapTapped(LatLng position) {
//     setState(() {
//       _selectedLocation = position;
//     });
//     _updateAddress(position);
//     _mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: position, zoom: 16),
//       ),
//     );
//   }

//   void _saveLocation() {
//     if (_selectedLocation != null) {
//       Navigator.pop(context, <String, dynamic>{
//         'location': _selectedLocation,
//         'address': _address,
//         'detailedAddress': _detailedAddress,
//       });
//     }
//   }

//   void _showSnackBar(String message, IconData icon) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(icon, color: Colors.white),
//             const SizedBox(width: 12),
//             Expanded(child: Text(message)),
//           ],
//         ),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _mapController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         title: const Text('Select Delivery Location'),
//         backgroundColor: Colors.white.withOpacity(0.95),
//         elevation: 0,
//         foregroundColor: Colors.black87,
//         actions: [
//           PopupMenuButton<MapType>(
//             icon: const Icon(Icons.layers_outlined),
//             tooltip: 'Map Type',
//             onSelected: (MapType value) {
//               setState(() => _mapType = value);
//             },
//             itemBuilder: (context) => [
//               const PopupMenuItem(
//                 value: MapType.normal,
//                 child: Row(
//                   children: [
//                     Icon(Icons.map_outlined, size: 20),
//                     SizedBox(width: 12),
//                     Text('Normal'),
//                   ],
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: MapType.satellite,
//                 child: Row(
//                   children: [
//                     Icon(Icons.satellite_alt, size: 20),
//                     SizedBox(width: 12),
//                     Text('Satellite'),
//                   ],
//                 ),
//               ),
//               const PopupMenuItem(
//                 value: MapType.hybrid,
//                 child: Row(
//                   children: [
//                     Icon(Icons.terrain, size: 20),
//                     SizedBox(width: 12),
//                     Text('Hybrid'),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const CircularProgressIndicator(),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Getting your location...',
//                     style: Theme.of(context).textTheme.bodyLarge,
//                   ),
//                 ],
//               ),
//             )
//           : _selectedLocation == null
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.location_off,
//                           size: 64, color: Colors.grey[400]),
//                       const SizedBox(height: 16),
//                       Text(
//                         'Location not available',
//                         style: Theme.of(context).textTheme.titleLarge,
//                       ),
//                       const SizedBox(height: 8),
//                       ElevatedButton.icon(
//                         onPressed: _getCurrentLocation,
//                         icon: const Icon(Icons.refresh),
//                         label: const Text('Retry'),
//                       ),
//                     ],
//                   ),
//                 )
//               : Stack(
//                   children: [
//                     GoogleMap(
//                       mapType: _mapType,
//                       onMapCreated: (GoogleMapController controller) {
//                         _mapController = controller;
//                         _updateAddress(_selectedLocation!);
//                       },
//                       onTap: _onMapTapped,
//                       initialCameraPosition: CameraPosition(
//                         target: _selectedLocation!,
//                         zoom: 15,
//                       ),
//                       markers: {
//                         Marker(
//                           markerId: const MarkerId('selected'),
//                           position: _selectedLocation!,
//                           draggable: true,
//                           onDragEnd: _onMapTapped,
//                           icon: BitmapDescriptor.defaultMarkerWithHue(
//                             BitmapDescriptor.hueRed,
//                           ),
//                         ),
//                       },
//                       myLocationEnabled: true,
//                       myLocationButtonEnabled: true,
//                       zoomControlsEnabled: false,
//                       compassEnabled: true,
//                       mapToolbarEnabled: false,
//                     ),
//                     // Location info card
//                     Positioned(
//                       left: 16,
//                       right: 16,
//                       bottom: 16,
//                       child: Material(
//                         elevation: 8,
//                         borderRadius: BorderRadius.circular(16),
//                         child: Container(
//                           padding: const EdgeInsets.all(20),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   Container(
//                                     padding: const EdgeInsets.all(8),
//                                     decoration: BoxDecoration(
//                                       color: Colors.red.shade50,
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                     child: Icon(
//                                       Icons.location_on,
//                                       color: Colors.red.shade400,
//                                       size: 24,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           'Delivery Location',
//                                           style: TextStyle(
//                                             fontSize: 12,
//                                             color: Colors.grey[600],
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 2),
//                                         Text(
//                                           _address.isEmpty
//                                               ? 'Loading address...'
//                                               : _address,
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w600,
//                                             color: Colors.black87,
//                                           ),
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                         if (_detailedAddress.isNotEmpty) ...[
//                                           const SizedBox(height: 2),
//                                           Text(
//                                             _detailedAddress,
//                                             style: TextStyle(
//                                               fontSize: 13,
//                                               color: Colors.grey[600],
//                                             ),
//                                             maxLines: 1,
//                                             overflow: TextOverflow.ellipsis,
//                                           ),
//                                         ],
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 16),
//                               SizedBox(
//                                 width: double.infinity,
//                                 height: 50,
//                                 child: ElevatedButton(
//                                   onPressed: _selectedLocation != null
//                                       ? _saveLocation
//                                       : null,
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.red.shade400,
//                                     foregroundColor: Colors.white,
//                                     elevation: 0,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                   ),
//                                   child: const Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(Icons.check_circle_outline,
//                                           size: 20),
//                                       SizedBox(width: 8),
//                                       Text(
//                                         'Confirm Location',
//                                         style: TextStyle(
//                                           fontSize: 16,
//                                           fontWeight: FontWeight.w600,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                     // Instruction hint
//                     Positioned(
//                       top: kToolbarHeight + 60,
//                       left: 16,
//                       right: 16,
//                       child: Material(
//                         elevation: 4,
//                         borderRadius: BorderRadius.circular(12),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 16, vertical: 12),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Row(
//                             children: [
//                               Icon(Icons.info_outline,
//                                   size: 20, color: Colors.blue[700]),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: Text(
//                                   'Tap on the map or drag the marker to select location',
//                                   style: TextStyle(
//                                     fontSize: 13,
//                                     color: Colors.grey[800],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChangeLocationScreen extends StatefulWidget {
  const ChangeLocationScreen({super.key});

  @override
  _ChangeLocationScreenState createState() => _ChangeLocationScreenState();
}

class _ChangeLocationScreenState extends State<ChangeLocationScreen> {
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  String _address = '';
  String _detailedAddress = '';
  MapType _mapType = MapType.normal;
  bool _isLoading = false;

  // Add your Geoapify API key here
  static const String _geoapifyApiKey = '46d6b25bcfb743a290349dbe55f79528';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showSnackBar('Please enable location services', Icons.location_off);
        }
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showSnackBar('Location permission denied', Icons.error_outline);
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnackBar(
              'Location permission permanently denied. Please enable in settings.',
              Icons.warning);
        }
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _updateAddress(_selectedLocation!);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error getting location: $e', Icons.error);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      // Geoapify Reverse Geocoding API
      final url = Uri.parse(
        'https://api.geoapify.com/v1/geocode/reverse?lat=${position.latitude}&lon=${position.longitude}&apiKey=$_geoapifyApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;

        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final Map<String, dynamic> properties = (data['features'] as List)[0]
              ['properties'] as Map<String, dynamic>;

          if (mounted) {
            setState(() {
              // Extract street address
              _address = (properties['street'] as String?) ??
                  (properties['address_line1'] as String?) ??
                  (properties['formatted'] as String?) ??
                  'Unknown Street';

              // Build detailed address from available components
              final List<String> addressParts = [];

              if (properties['suburb'] != null) {
                addressParts.add(properties['suburb'] as String);
              }
              if (properties['city'] != null) {
                addressParts.add(properties['city'] as String);
              }
              if (properties['state'] != null) {
                addressParts.add(properties['state'] as String);
              }
              if (properties['country'] != null) {
                addressParts.add(properties['country'] as String);
              }

              _detailedAddress = addressParts.join(', ');
            });
          }
        }
      } else {
        throw Exception('Failed to load address: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      if (mounted) {
        setState(() {
          _address = 'Unable to load address';
          _detailedAddress = '';
        });
      }
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _updateAddress(position);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16),
      ),
    );
  }

  void _saveLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, <String, dynamic>{
        'location': _selectedLocation,
        'address': _address,
        'detailedAddress': _detailedAddress,
      });
    }
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Map Type',
            onSelected: (MapType value) {
              setState(() => _mapType = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: MapType.normal,
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Normal'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MapType.satellite,
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt, size: 20),
                    SizedBox(width: 12),
                    Text('Satellite'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: MapType.hybrid,
                child: Row(
                  children: [
                    Icon(Icons.terrain, size: 20),
                    SizedBox(width: 12),
                    Text('Hybrid'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Getting your location...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : _selectedLocation == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Location not available',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      mapType: _mapType,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        _updateAddress(_selectedLocation!);
                      },
                      onTap: _onMapTapped,
                      initialCameraPosition: CameraPosition(
                        target: _selectedLocation!,
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: _selectedLocation!,
                          draggable: true,
                          onDragEnd: _onMapTapped,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: false,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                    // Location info card
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.red.shade400,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery Location',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _address.isEmpty
                                              ? 'Loading address...'
                                              : _address,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_detailedAddress.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            _detailedAddress,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _selectedLocation != null
                                      ? _saveLocation
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade400,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Confirm Location',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Instruction hint
                    Positioned(
                      top: kToolbarHeight + 60,
                      left: 16,
                      right: 16,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 20, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tap on the map or drag the marker to select location',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
