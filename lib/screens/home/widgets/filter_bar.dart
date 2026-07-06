// ============================================
//  lib/screens/home/widgets/filter_and_radius_bar.dart
// ============================================
import 'package:flutter/material.dart';
import 'package:aquagas/screens/models/filter_option.dart';

/// Combined FilterBar and RadiusSlider widget
/// Shows filter chips and radius slider appears when "Search Radius" is clicked

class FilterAndRadiusBar extends StatefulWidget {
  final FilterOption selectedFilter;
  final void Function(FilterOption) onFilterChanged;
  final double radius;
  final Function(double) onRadiusChanged;

  const FilterAndRadiusBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.radius,
    required this.onRadiusChanged,
  });

  @override
  State<FilterAndRadiusBar> createState() => _FilterAndRadiusBarState();
}

class _FilterAndRadiusBarState extends State<FilterAndRadiusBar> {
  bool _showRadiusSlider = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar Section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter By',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: <Widget>[
                    _filterChip(
                      'Nearest',
                      FilterOption.nearest,
                      Icons.near_me,
                    ),
                    const SizedBox(width: 10),
                    _filterChip(
                      'Price: Low-High',
                      FilterOption.priceAsc,
                      Icons.arrow_upward,
                    ),
                    const SizedBox(width: 10),
                    _filterChip(
                      'Price: High-Low',
                      FilterOption.priceDesc,
                      Icons.arrow_downward,
                    ),
                    const SizedBox(width: 10),
                    _filterChip(
                      'Top Rated',
                      FilterOption.rating,
                      Icons.star,
                    ),
                    const SizedBox(width: 10),
                    _filterChip(
                      'In Stock',
                      FilterOption.availability,
                      Icons.check_circle,
                    ),
                    const SizedBox(width: 10),
                    // Search Radius Filter Chip
                    _radiusFilterChip(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Radius Slider Section (Appears when radius filter is clicked)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _showRadiusSlider
              ? Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade50,
                        Colors.blue.shade100.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade300.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_searching,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Search Radius',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '${widget.radius.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blue.shade700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'km',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Quick Distance Chips
                          _buildQuickChip('Near', widget.radius <= 3.0,
                              () => widget.onRadiusChanged(2.0)),
                          const SizedBox(width: 6),
                          _buildQuickChip('Far', widget.radius > 6.0,
                              () => widget.onRadiusChanged(8.0)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Custom Slider Track
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 6,
                          activeTrackColor: Colors.blue.shade600,
                          inactiveTrackColor: Colors.blue.shade100,
                          thumbColor: Colors.blue.shade700,
                          overlayColor: Colors.blue.shade200.withOpacity(0.3),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12,
                            elevation: 4,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 24,
                          ),
                          valueIndicatorColor: Colors.blue.shade700,
                          valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          activeTickMarkColor: Colors.transparent,
                          inactiveTickMarkColor: Colors.transparent,
                        ),
                        child: Slider(
                          value: widget.radius,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          label: '${widget.radius.toStringAsFixed(1)} km',
                          onChanged: widget.onRadiusChanged,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Range Labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRangeLabel('1 km', true),
                          _buildRangeLabel('5 km', false),
                          _buildRangeLabel('10 km', false),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _filterChip(String title, FilterOption option, IconData icon) {
    final bool isSelected = widget.selectedFilter == option;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onFilterChanged(option),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade700,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.shade300.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radiusFilterChip() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showRadiusSlider = !_showRadiusSlider;
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: _showRadiusSlider
                ? LinearGradient(
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade700,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: _showRadiusSlider ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _showRadiusSlider
                  ? Colors.blue.shade700
                  : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: _showRadiusSlider
                ? [
                    BoxShadow(
                      color: Colors.blue.shade300.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_searching,
                size: 16,
                color: _showRadiusSlider ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Search Radius',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      _showRadiusSlider ? FontWeight.w600 : FontWeight.w500,
                  color:
                      _showRadiusSlider ? Colors.white : Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _showRadiusSlider ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: _showRadiusSlider ? Colors.white : Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.blue.shade700 : Colors.blue.shade300,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeLabel(String label, bool isStart) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade600,
      ),
    );
  }
}

/*
USAGE:

Replace both FilterBar and RadiusSlider with this single widget:

FilterAndRadiusBar(
  selectedFilter: _selectedFilter,
  onFilterChanged: (FilterOption filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  },
  radius: _radius,
  onRadiusChanged: (double value) {
    setState(() {
      _radius = value;
    });
    _fetchProducts(_currentLat, _currentLng);
  },
)

The radius slider will now appear/disappear when you click the "Search Radius" filter chip!
*/
