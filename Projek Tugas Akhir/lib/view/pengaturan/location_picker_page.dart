import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationPickerPage({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchC = TextEditingController();

  late LatLng _posisiTengah;
  bool _sedangMemuatGPS = false;
  bool _sedangMemuatAlamat = false;
  bool _sedangMencari = false;
  String _alamatTerpilih = "Mengambil alamat...";

  List<dynamic> _sugestiLokasi = [];
  Timer? _searchDebounce;
  Timer? _geocodeDebounce;

  static const LatLng _defaultJakarta = LatLng(-6.200000, 106.816666);

  @override
  void initState() {
    super.initState();
    _posisiTengah = widget.initialLocation ?? _defaultJakarta;
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _alamatTerpilih = widget.initialAddress!;
    }

    _inisialisasiLokasi();
  }

  @override
  void dispose() {
    _searchC.dispose();
    _searchDebounce?.cancel();
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _inisialisasiLokasi() async {
    if (widget.initialLocation != null) {
      if (widget.initialAddress == null) {
        _updateAlamatDebounced(_posisiTengah);
      }
      return;
    }

    await _dapatkanLokasiAwal();
  }

  // Fetch initial or refreshed GPS position with full error & permission handling
  Future<void> _dapatkanLokasiAwal() async {
    if (!mounted) return;
    setState(() => _sedangMemuatGPS = true);

    try {
      // 1. Check if location services are enabled on device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _tampilkanSnackBarWithAction(
          "Layanan lokasi (GPS) belum aktif.",
          "Aktifkan",
          () async => await Geolocator.openLocationSettings(),
        );
        setState(() => _sedangMemuatGPS = false);
        _updateAlamatDebounced(_posisiTengah);
        return;
      }

      // 2. Check & Request Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _tampilkanSnackBar("Izin lokasi ditolak.");
          setState(() => _sedangMemuatGPS = false);
          _updateAlamatDebounced(_posisiTengah);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _tampilkanSnackBarWithAction(
          "Izin lokasi ditolak permanen. Buka pengaturan untuk mengaktifkan.",
          "Pengaturan",
          () async => await Geolocator.openAppSettings(),
        );
        setState(() => _sedangMemuatGPS = false);
        _updateAlamatDebounced(_posisiTengah);
        return;
      }

      // 3. Try Quick Last Known Position first if available for instant UI feedback
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        LatLng posBaru = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _posisiTengah = posBaru;
        });
        _mapController.move(posBaru, 16);
      }

      // 4. Fetch precise Current Position with platform-specific settings
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 15),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        );
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (!mounted) return;
      LatLng posBaru = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _posisiTengah = posBaru;
        _sedangMemuatGPS = false;
      });

      _mapController.move(posBaru, 16);
      _updateAlamatDebounced(posBaru);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sedangMemuatGPS = false);
      _tampilkanSnackBar("Gagal mendapatkan lokasi GPS terkini. Pastikan GPS aktif dan sinyal stabil.");
      _updateAlamatDebounced(_posisiTengah);
    }
  }

  // Debounced reverse geocoding to prevent excessive requests to Nominatim
  void _updateAlamatDebounced(LatLng pos) {
    _geocodeDebounce?.cancel();
    if (mounted) {
      setState(() => _sedangMemuatAlamat = true);
    }

    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      _fetchAlamatDariNominatim(pos);
    });
  }

  // Fetch address from Nominatim API
  Future<void> _fetchAlamatDariNominatim(LatLng pos) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TugasAkhirPOSApp/1.0 (com.aplikasisaya.pos)',
          'Accept-Language': 'id,en',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String displayName = data['display_name'] ?? '';

        if (displayName.isNotEmpty) {
          setState(() {
            _alamatTerpilih = displayName;
            _sedangMemuatAlamat = false;
          });
          return;
        }
      }
      setState(() {
        _alamatTerpilih = "Alamat tidak ditemukan (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})";
        _sedangMemuatAlamat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alamatTerpilih = "Gagal mengambil alamat. Silakan periksa koneksi internet.";
        _sedangMemuatAlamat = false;
      });
    }
  }

  // Debounced search / auto-complete
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() => _sugestiLokasi = []);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _sedangMencari = true);

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
        );

        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'TugasAkhirPOSApp/1.0 (com.aplikasisaya.pos)',
            'Accept-Language': 'id,en',
          },
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          setState(() {
            _sugestiLokasi = data;
          });
        }
      } catch (_) {
        // Ignore search network errors
      } finally {
        if (mounted) setState(() => _sedangMencari = false);
      }
    });
  }

  // Handle tap on search suggestion item
  void _pilihSugesti(dynamic item) {
    double? lat = double.tryParse(item['lat']?.toString() ?? '');
    double? lon = double.tryParse(item['lon']?.toString() ?? '');

    if (lat == null || lon == null) return;

    LatLng targetBaru = LatLng(lat, lon);
    String namaLengkap = item['display_name'] ?? '';

    _searchC.text = namaLengkap;
    setState(() {
      _sugestiLokasi = [];
      _alamatTerpilih = namaLengkap;
      _posisiTengah = targetBaru;
      _sedangMemuatAlamat = false;
    });

    FocusScope.of(context).unfocus();
    _mapController.move(targetBaru, 16);
  }

  void _tampilkanSnackBar(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _tampilkanSnackBarWithAction(String pesan, String actionLabel, VoidCallback onPressed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: actionLabel,
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Lokasi Toko"),
        elevation: 1,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (_sugestiLokasi.isNotEmpty) {
            setState(() => _sugestiLokasi = []);
          }
        },
        child: Stack(
          children: [
            // 1. PETA FLUTTER MAP
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
                    _updateAlamatDebounced(_posisiTengah);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aplikasisaya.pos',
                ),
              ],
            ),

            // 2. PIN MERAH PRESISI TINGGI DI TENGAH MAP
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Geser peta untuk mengubah",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.location_on,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),

            // 3. SEARCH BAR & LIST SUGESTI
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _searchC,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: "Cari nama jalan / kota / tempat...",
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: Colors.blue),
                          suffixIcon: _sedangMencari
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : _searchC.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
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
                      elevation: 6,
                      margin: const EdgeInsets.only(top: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: Scrollbar(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _sugestiLokasi.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _sugestiLokasi[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_city, size: 20, color: Colors.blueAccent),
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

            // 4. KONTROL TOMBOL ZOOM & MY LOCATION (GPS)
            Positioned(
              right: 16,
              bottom: 210,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: "btn_gps",
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    onPressed: _sedangMemuatGPS ? null : _dapatkanLokasiAwal,
                    child: _sedangMemuatGPS
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: "btn_zoom_in",
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_posisiTengah, (currentZoom + 1).clamp(3.0, 18.0));
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
                      _mapController.move(_posisiTengah, (currentZoom - 1).clamp(3.0, 18.0));
                    },
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),

            // 5. CARD BOTTOM INFO ALAMAT & COORD
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.store, color: Colors.blue, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Lokasi Terpilih",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (_sedangMemuatAlamat)
                                  const Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Mengecek alamat...",
                                        style: TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    _alamatTerpilih,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Koordinat: ${_posisiTengah.latitude.toStringAsFixed(6)}, ${_posisiTengah.longitude.toStringAsFixed(6)}",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _sedangMemuatAlamat
                            ? null
                            : () {
                                Navigator.pop(context, {
                                  'alamatFormatted': _alamatTerpilih,
                                  'latitude': _posisiTengah.latitude,
                                });
                              },
                        child: const Text(
                          "PILIH LOKASI INI",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
