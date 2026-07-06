import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Vendor extends Equatable {
  final String id;
  final String name;
  final LatLng location;
  final double rating;
  final bool isOpen;
  final String phone;
  final String address;
  final String category;

  const Vendor({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.isOpen,
    required this.phone,
    required this.address,
    required this.category,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> locationJson =
        json['location'] as Map<String, dynamic>;
    return Vendor(
      id: json['id'] as String,
      name: json['name'] as String,
      location: LatLng(
        (locationJson['lat'] as num).toDouble(),
        (locationJson['lng'] as num).toDouble(),
      ),
      rating: (json['rating'] as num).toDouble(),
      isOpen: json['is_open'] as bool,
      phone: json['phone'] as String,
      address: json['address'] as String,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'location': <String, double>{
          'lat': location.latitude,
          'lng': location.longitude,
        },
        'rating': rating,
        'is_open': isOpen,
        'phone': phone,
        'address': address,
        'category': category,
      };

  @override
  List<Object> get props =>
      <Object>[id, name, location, rating, isOpen, phone, address, category];
}
