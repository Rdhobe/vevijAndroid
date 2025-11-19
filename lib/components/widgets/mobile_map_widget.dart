// mobile_map_widget.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:vevij/models/employee/employee_location_data.dart';

class MapWidget extends StatefulWidget {
  final List<EmployeeLocationData> employees;

  const MapWidget({super.key, required this.employees});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _updateMapMarkers();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employees != widget.employees) {
      _updateMapMarkers();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMapMarkers() {
    Set<Marker> newMarkers = {};
    
    for (var employee in widget.employees) {
      if (employee.currentLocation != null && employee.currentLocation!.isNotEmpty) {
        try {
          List<String> coords = employee.currentLocation!.split(', ');
          if (coords.length == 2) {
            double lat = double.parse(coords[0]);
            double lng = double.parse(coords[1]);
            
            BitmapDescriptor markerIcon = _getMarkerIcon(employee.workStatus);
            
            newMarkers.add(
              Marker(
                markerId: MarkerId(employee.userId),
                position: LatLng(lat, lng),
                icon: markerIcon,
                infoWindow: InfoWindow(
                  title: employee.empName,
                  snippet: '${employee.workStatus} • ID: ${employee.empId}',
                  onTap: () => _showEmployeeDetails(employee),
                ),
                onTap: () => _showEmployeeMapDetails(employee),
              ),
            );
          }
        } catch (e) {
          print('Error parsing coordinates for ${employee.empName}: $e');
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  BitmapDescriptor _getMarkerIcon(String status) {
    switch (status) {
      case 'Working':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'On Break':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'Offline':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  LatLng _calculateCenterPoint() {
    if (widget.employees.isEmpty) {
      return LatLng(18.5204, 73.8567); // Default to Pune coordinates
    }

    List<LatLng> validLocations = [];
    
    for (var employee in widget.employees) {
      if (employee.currentLocation != null && employee.currentLocation!.isNotEmpty) {
        try {
          List<String> coords = employee.currentLocation!.split(', ');
          if (coords.length == 2) {
            double lat = double.parse(coords[0]);
            double lng = double.parse(coords[1]);
            validLocations.add(LatLng(lat, lng));
          }
        } catch (e) {
          // Skip invalid coordinates
        }
      }
    }

    if (validLocations.isEmpty) {
      return LatLng(18.5204, 73.8567); // Default to Pune coordinates
    }

    // Calculate average center point
    double totalLat = validLocations.fold(0.0, (sum, location) => sum + location.latitude);
    double totalLng = validLocations.fold(0.0, (sum, location) => sum + location.longitude);
    
    return LatLng(
      totalLat / validLocations.length,
      totalLng / validLocations.length,
    );
  }

  void _showEmployeeMapDetails(EmployeeLocationData employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(employee.workStatus).withOpacity(0.2),
              child: Text(
                employee.empName.isNotEmpty ? employee.empName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: _getStatusColor(employee.workStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.empName),
                  Text(
                    'ID: ${employee.empId}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusChip(employee.workStatus, _getStatusColor(employee.workStatus)),
            SizedBox(height: 12),
            if (employee.todayLoginTime != null)
              Text('Login Time: ${employee.todayLoginTime}'),
            if (employee.currentWorkDuration != null)
              Text('Work Duration: ${employee.currentWorkDuration}'),
            if (employee.lastLocationUpdate != null)
              Text('Last Update: ${_formatTimestamp(employee.lastLocationUpdate!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (employee.currentLocation != null)
            ElevatedButton.icon(
              icon: Icon(Icons.directions),
              label: Text('Get Directions'),
              onPressed: () {
                Navigator.pop(context);
                _openLocation(employee.currentLocation!);
              },
            ),
        ],
      ),
    );
  }

  void _showEmployeeDetails(EmployeeLocationData employee) {
    _showEmployeeMapDetails(employee);
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Working':
        return Colors.green;
      case 'On Break':
        return Colors.orange;
      case 'Offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime;
    if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      dateTime = timestamp.toDate();
    }
    
    Duration difference = DateTime.now().difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _openLocation(String coordinates) async {
    try {
      List<String> coords = coordinates.split(', ');
      if (coords.length == 2) {
        double lat = double.parse(coords[0]);
        double lng = double.parse(coords[1]);
        
        String googleMapsUrl = 'https://www.google.com/maps?q=$lat,$lng';
        
        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
          await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open maps'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid coordinates format'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng centerPoint = _calculateCenterPoint();
    
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: centerPoint,
        zoom: 12.0,
      ),
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      markers: _markers,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      compassEnabled: true,
    );
  }
}
