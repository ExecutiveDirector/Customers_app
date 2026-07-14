// lib/screens/nearby_outlets_screen.dart
import 'package:flutter/material.dart';
import 'package:aquagas/services/outlet_service.dart';
import 'package:geolocator/geolocator.dart';

class NearbyVendorsScreen extends StatefulWidget {
  const NearbyVendorsScreen({super.key});

  @override
  State<NearbyVendorsScreen> createState() => _NearbyVendorsScreenState();
}

class _NearbyVendorsScreenState extends State<NearbyVendorsScreen> {
  final OutletService _outletService = OutletService();

  List<Map<String, dynamic>> _outlets = [];
  List<Map<String, dynamic>> _filteredOutlets = [];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isLoadingLocation = true;
  Position? _userLocation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _getUserLocationAndFetchOutlets();
    _searchController.addListener(_filterOutlets);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================================
  // Location & Data Fetching
  // =========================================================================

  Future<void> _getUserLocationAndFetchOutlets() async {
    setState(() {
      _isLoading = true;
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      // Get location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage =
                'Location permissions are required to find nearby outlets';
            _isLoading = false;
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage =
              'Location permissions permanently denied. Please enable in settings.';
          _isLoading = false;
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _userLocation = position;
        _isLoadingLocation = false;
      });

      debugPrint(
          '馃搷 User location: ${position.latitude}, ${position.longitude}');

      // Fetch nearby outlets
      await _fetchNearbyOutlets(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('鉂� Error getting location: $e');
      setState(() {
        _errorMessage = 'Failed to get your location: $e';
        _isLoading = false;
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _fetchNearbyOutlets(double latitude, double longitude) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final outlets = await _outletService.getNearbyOutlets(
        latitude: latitude,
        longitude: longitude,
        radiusKm: 50, // 50km radius
        limit: 50,
      );

      setState(() {
        _outlets = outlets;
        _filteredOutlets = outlets;
        _isLoading = false;
      });

      debugPrint('鉁� Loaded ${outlets.length} nearby outlets');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  // =========================================================================
  // Filtering
  // =========================================================================

  void _filterOutlets() {
    setState(() {
      _filteredOutlets = _outlets.where((outlet) {
        final name = outlet['outlet_name']?.toString().toLowerCase() ?? '';
        final address = outlet['address']?.toString().toLowerCase() ?? '';
        final vendorName =
            outlet['vendor_name']?.toString().toLowerCase() ?? '';
        final searchQuery = _searchController.text.toLowerCase();

        final matchesSearch = name.contains(searchQuery) ||
            address.contains(searchQuery) ||
            vendorName.contains(searchQuery);

        final isOpen = outlet['is_open'] == true;
        // null distance_km means this outlet is exempt from location
        // restriction (nationwide vendor) 鈥� treat as "not nearby" for the
        // 'Nearest' filter rather than defaulting to 0.0, which would
        // otherwise wrongly count it as the closest possible outlet.
        final bool isNationwide =
            outlet['nationwide'] == true || outlet['distance_km'] == null;
        final double? distance = isNationwide
            ? null
            : (outlet['distance_km'] as num?)?.toDouble();

        final matchesFilter = _selectedFilter == 'All' ||
            (_selectedFilter == 'Open' && isOpen) ||
            (_selectedFilter == 'Closed' && !isOpen) ||
            (_selectedFilter == 'Nearest' &&
                distance != null &&
                distance <= 10.0);

        return matchesSearch && matchesFilter;
      }).toList();

      // Sort by distance 鈥� nationwide outlets (no distance) sort to the end
      _filteredOutlets.sort((a, b) {
        final distA = (a['distance_km'] as num?)?.toDouble() ?? double.infinity;
        final distB = (b['distance_km'] as num?)?.toDouble() ?? double.infinity;
        return distA.compareTo(distB);
      });
    });
  }

  // =========================================================================
  // UI Helpers
  // =========================================================================

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message.replaceAll('Exception: ', ''))),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  // =========================================================================
  // Build Methods
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Nearby Outlets',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _userLocation != null
                ? () => _fetchNearbyOutlets(
                      _userLocation!.latitude,
                      _userLocation!.longitude,
                    )
                : null,
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green.shade600),
                  const SizedBox(height: 16),
                  Text(
                    _isLoadingLocation
                        ? 'Getting your location...'
                        : 'Loading nearby outlets...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildOutletsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _getUserLocationAndFetchOutlets,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletsList() {
    return Column(
      children: [
        // Search and filter section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search outlets or vendors...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nearest'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Open'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Closed'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Outlets count
        if (_filteredOutlets.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${_filteredOutlets.length} outlet${_filteredOutlets.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Outlets list
        Expanded(
          child: _filteredOutlets.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _filteredOutlets.length,
                  itemBuilder: (context, index) {
                    return _buildOutletCard(_filteredOutlets[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No outlets found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _filterOutlets();
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade700 : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? Colors.green.shade300 : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildOutletCard(Map<String, dynamic> outlet) {
    final outletName = outlet['outlet_name']?.toString() ?? 'Unknown Outlet';
    final vendorName = outlet['vendor_name']?.toString() ?? '';
    final address = outlet['address']?.toString() ?? 'Address not available';
    final bool isNationwide =
        outlet['nationwide'] == true || outlet['distance_km'] == null;
    final distanceKm = (outlet['distance_km'] as num?)?.toDouble() ?? 0.0;
    final isOpen = outlet['is_open'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            debugPrint('Tapped outlet: $outletName');
            // Navigate to outlet products screen
            Navigator.pushNamed(
              context,
              '/outlet-products',
              arguments: outlet,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Outlet icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.store,
                        color: Colors.green.shade600,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Outlet info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outletName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (vendorName.isNotEmpty)
                            Text(
                              vendorName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isOpen ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOpen
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOpen
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Distance (or nationwide badge for location-exempt vendors)
                Row(
                  children: [
                    Icon(
                      isNationwide ? Icons.public : Icons.navigation,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isNationwide
                          ? 'Delivers Nationwide'
                          : _formatDistance(distanceKm),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    if (!isNationwide) ...[
                      const SizedBox(width: 4),
                      Text(
                        'away',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Address
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/outlet-products',
                        arguments: outlet,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'View Products',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
