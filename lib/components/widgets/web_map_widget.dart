import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'package:vevij/models/employee/employee_location_data.dart';
class MapWidget extends StatefulWidget {
  final List<EmployeeLocationData> employees;

  const MapWidget({super.key, required this.employees});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late String _mapHtmlId;
  html.IFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _mapHtmlId = 'map-${DateTime.now().millisecondsSinceEpoch}';
    _registerMapView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateEmployeesOnMap();
    });
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employees != widget.employees) {
      _updateEmployeesOnMap();
    }
  }

  void _registerMapView() {
    _iframeElement = html.IFrameElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..srcdoc = _getMapHtml();

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_mapHtmlId, (int viewId) {
      return _iframeElement!;
    });
  }

  void _updateEmployeesOnMap() {
    if (_iframeElement != null && widget.employees.isNotEmpty) {
      final employeeData = widget.employees
          .where((emp) => emp.currentLocation != null)
          .map((emp) => {
                'empName': emp.empName,
                'empId': emp.empId,
                'workStatus': emp.workStatus,
                'currentLocation': emp.currentLocation,
                'todayLoginTime': emp.todayLoginTime ?? '',
                'currentWorkDuration': emp.currentWorkDuration ?? '',
              })
          .toList();

      // Send message to iframe
      final message = {
        'type': 'updateEmployees',
        'employees': employeeData,
      };

      _iframeElement!.contentWindow?.postMessage(jsonEncode(message), '*');
    }
  }

  String _getMapHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Employee Location Map</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" 
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    <style>
        body { 
            margin: 0; 
            padding: 0; 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #map { 
            height: 100vh; 
            width: 100%; 
        }
        .custom-div-icon {
            background: none;
            border: none;
        }
        .marker-pin {
            width: 25px;
            height: 25px;
            border-radius: 50% 50% 50% 0;
            position: absolute;
            transform: rotate(-45deg);
            left: 50%;
            top: 50%;
            margin: -12px 0 0 -12px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        .marker-pin::after {
            content: '';
            width: 8px;
            height: 8px;
            background: white;
            position: absolute;
            border-radius: 50%;
            transform: rotate(45deg);
        }
        .working { background: #4CAF50; }
        .break { background: #FF9800; }
        .offline { background: #F44336; }
        .legend {
            position: absolute;
            top: 20px;
            right: 20px;
            background: white;
            padding: 15px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
            z-index: 1000;
            min-width: 120px;
        }
        .legend h4 {
            margin: 0 0 10px 0;
            font-size: 14px;
            color: #333;
        }
        .legend-item {
            display: flex;
            align-items: center;
            margin-bottom: 8px;
            font-size: 12px;
        }
        .legend-color {
            width: 16px;
            height: 16px;
            border-radius: 50% 50% 50% 0;
            margin-right: 8px;
            transform: rotate(-45deg);
        }
        .popup-content {
            min-width: 200px;
            font-family: inherit;
        }
        .popup-content h4 {
            margin: 0 0 10px 0;
            color: #333;
            font-size: 16px;
        }
        .popup-content p {
            margin: 5px 0;
            color: #666;
            font-size: 13px;
        }
        .popup-content .status {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 500;
            margin: 5px 0;
        }
        .status.working { background: #E8F5E8; color: #4CAF50; }
        .status.break { background: #FFF3E0; color: #FF9800; }
        .status.offline { background: #FFEBEE; color: #F44336; }
        .popup-content a {
            color: #2196F3;
            text-decoration: none;
            font-weight: 500;
        }
        .popup-content a:hover {
            text-decoration: underline;
        }
        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            text-align: center;
            z-index: 1000;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <div class="legend">
        <h4>Employee Status</h4>
        <div class="legend-item">
            <div class="legend-color working"></div>
            <span>Working</span>
        </div>
        <div class="legend-item">
            <div class="legend-color break"></div>
            <span>On Break</span>
        </div>
        <div class="legend-item">
            <div class="legend-color offline"></div>
            <span>Offline</span>
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
            integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <script>
        // Initialize map
        var map = L.map('map').setView([18.5204, 73.8567], 12);
        
        // Add tile layer
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);

        var markers = [];
        var markerGroup = L.layerGroup().addTo(map);

        function clearMarkers() {
            markerGroup.clearLayers();
            markers = [];
        }

        function getStatusClass(status) {
            switch(status) {
                case 'Working': return 'working';
                case 'On Break': return 'break';
                case 'Offline': return 'offline';
                default: return 'offline';
            }
        }

        function addEmployeeMarker(employee) {
            if (!employee.currentLocation) return;
            
            const coords = employee.currentLocation.split(', ');
            if (coords.length !== 2) return;
            
            const lat = parseFloat(coords[0]);
            const lng = parseFloat(coords[1]);
            
            if (isNaN(lat) || isNaN(lng)) return;

            const statusClass = getStatusClass(employee.workStatus);
            const initial = employee.empName ? employee.empName.charAt(0).toUpperCase() : 'U';
            
            const customIcon = L.divIcon({
                className: 'custom-div-icon',
                html: '<div class="marker-pin ' + statusClass + '">' + initial + '</div>',
                iconSize: [25, 35],
                iconAnchor: [12, 35],
                popupAnchor: [0, -35]
            });

            const popupContent = 
                '<div class="popup-content">' +
                '<h4>' + employee.empName + '</h4>' +
                '<p><strong>ID:</strong> ' + employee.empId + '</p>' +
                '<div class="status ' + statusClass + '">' + employee.workStatus + '</div>' +
                (employee.todayLoginTime ? '<p><strong>Login:</strong> ' + employee.todayLoginTime + '</p>' : '') +
                (employee.currentWorkDuration ? '<p><strong>Duration:</strong> ' + employee.currentWorkDuration + '</p>' : '') +
                '<p><a href="https://www.google.com/maps?q=' + lat + ',' + lng + '" target="_blank">📍 Get Directions</a></p>' +
                '</div>';

            const marker = L.marker([lat, lng], { icon: customIcon })
                .bindPopup(popupContent, {
                    maxWidth: 250,
                    className: 'custom-popup'
                });
            
            markerGroup.addLayer(marker);
            markers.push(marker);
        }

        function updateMap(employeesData) {
            clearMarkers();
            
            if (employeesData && employeesData.length > 0) {
                const validLocations = [];
                
                employeesData.forEach(employee => {
                    addEmployeeMarker(employee);
                    
                    if (employee.currentLocation) {
                        const coords = employee.currentLocation.split(', ');
                        if (coords.length === 2) {
                            const lat = parseFloat(coords[0]);
                            const lng = parseFloat(coords[1]);
                            if (!isNaN(lat) && !isNaN(lng)) {
                                validLocations.push([lat, lng]);
                            }
                        }
                    }
                });
                
                if (validLocations.length > 0) {
                    if (validLocations.length === 1) {
                        map.setView(validLocations[0], 15);
                    } else {
                        const group = new L.featureGroup(markers);
                        map.fitBounds(group.getBounds().pad(0.1));
                    }
                }
            }
        }

        // Listen for messages from Flutter
        window.addEventListener('message', function(event) {
            try {
                let data = event.data;
                if (typeof data === 'string') {
                    data = JSON.parse(data);
                }
                if (data.type === 'updateEmployees') {
                    updateMap(data.employees);
                }
            } catch (e) {
                console.error('Error parsing message:', e);
            }
        });

        // Initial empty state
        updateMap([]);
    </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return widget.employees.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'No employee locations available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Employee locations will appear here when available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        : HtmlElementView(viewType: _mapHtmlId);
  }
}
