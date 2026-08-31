import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchC = TextEditingController();

  LatLng _posisiTengah = const LatLng(-6.200000, 106.816666); // Default
  bool _sedangMemuat = true;
  bool _sedangMencari = false;
  String _alamatTerpilih = "Mengambil alamat...";

  List<dynamic> _sugestiLokasi = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _dapatkanLokasiAwal();
  }

  @override
  void dispose() {
    _searchC.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Ambil lokasi GPS HP
  Future<void> _dapatkanLokasiAwal() async {
    setState(() => _sedangMemuat = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      LatLng posBaru = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _posisiTengah = posBaru;
        _sedangMemuat = false;
      });

      _mapController.move(posBaru, 16);
      _updateAlamat(posBaru);
    } catch (e) {
      setState(() => _sedangMemuat = false);
      _updateAlamat(_posisiTengah);
    }
  }

  // Auto-complete Search
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() => _sugestiLokasi = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _sedangMencari = true);
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
        );

        final response = await http.get(url, headers: {
          'User-Agent': 'com.aplikasisaya.pos',
        });

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          setState(() {
            _sugestiLokasi = data;
          });
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _sedangMencari = false);
      }
    });
  }

  // Ketika item sugesti diklik
  void _pilihSugesti(dynamic item) {
    double lat = double.parse(item['lat']);
    double lon = double.parse(item['lon']);
    LatLng targetBaru = LatLng(lat, lon);

    String namaLengkap = item['display_name'] ?? '';

    _searchC.text = namaLengkap;
    setState(() {
      _sugestiLokasi = [];
      _alamatTerpilih = namaLengkap;
      _posisiTengah = targetBaru;
    });

    FocusScope.of(context).unfocus();
    _mapController.move(targetBaru, 16);
  }

  // Reverse Geocoding yang Detail & Akurat
  Future<void> _updateAlamat(LatLng pos) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'com.aplikasisaya.pos',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String displayName = data['display_name'] ?? '';

        if (displayName.isNotEmpty) {
          setState(() {
            _alamatTerpilih = displayName;
          });
        }
      }
    } catch (_) {
      setState(() => _alamatTerpilih = "Alamat tidak ditemukan");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pilih Lokasi Toko")),
      body: Stack(
        children: [
          // 1. PETA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _posisiTengah,
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (camera, hasGesture) {
                _posisiTengah = camera.center;
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _updateAlamat(_posisiTengah);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'com.aplikasisaya.pos',
              ),
            ],
          ),

          // 2. PIN MERAH
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Icon(
                Icons.location_on,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
          ),

          // 3. SEARCH BAR + SUGESTI
          Positioned(
            top: 12, left: 16, right: 16,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _searchC,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Cari nama jalan / kota / tempat...",
                        hintStyle: const TextStyle(fontSize: 13),
                        border: InputBorder.none,
                        icon: const Icon(Icons.search, color: Colors.blue),
                        suffixIcon: _sedangMencari
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                            : _searchC.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchC.clear();
                            setState(() => _sugestiLokasi = []);
                          },
                        )
                            : null,
                      ),
                    ),
                  ),
                ),

                if (_sugestiLokasi.isNotEmpty)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(top: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: Scrollbar(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _sugestiLokasi.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _sugestiLokasi[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_city, size: 20, color: Colors.grey),
                              title: Text(
                                item['display_name'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => _pilihSugesti(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. KONTROL ZOOM & GPS
          Positioned(
            right: 16,
            bottom: 160,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "btn_gps",
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  onPressed: _dapatkanLokasiAwal,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "btn_zoom_in",
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_posisiTengah, currentZoom + 1);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "btn_zoom_out",
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(_posisiTengah, currentZoom - 1);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          if (_sedangMemuat)
            Container(
              color: Colors.black.withValues(alpha: 0.1),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text("Mencari lokasi...", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 5. CARD BOTTOM INFO ALAMAT
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _alamatTerpilih,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          'alamatFormatted': _alamatTerpilih,
                          'latitude': _posisiTengah.latitude,
                          'longitude': _posisiTengah.longitude,
                        });
                      },
                      child: const Text("PILIH LOKASI INI"),
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
