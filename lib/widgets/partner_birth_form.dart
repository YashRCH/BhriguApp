import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/firebase_constants.dart';
import '../models/birth_place_suggestion.dart';
import '../models/partner_match_model.dart';

const _matchBlack = Color(0xFF050505);
const _matchPanel = Color(0xFF0D0B08);
const _matchPanelSoft = Color(0xFF15110A);
const _matchGold = Color(0xFFFFD88A);
const _matchWhite = Color(0xFFFFFFFF);
const _matchMuted = Color(0xCCFFFFFF);
const _matchLine = Color(0xFF3A301C);

class PartnerBirthForm extends StatefulWidget {
  final bool loading;
  final ValueChanged<PartnerBirthProfile> onSubmit;

  const PartnerBirthForm({
    super.key,
    required this.loading,
    required this.onSubmit,
  });

  @override
  State<PartnerBirthForm> createState() => _PartnerBirthFormState();
}

class _PartnerBirthFormState extends State<PartnerBirthForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  DateTime? _selectedDob;
  TimeOfDay? _selectedTime;
  double? _selectedLatitude;
  double? _selectedLongitude;

  Timer? _hintTimer;
  int _hintIndex = 0;

  static const List<String> _rotatingHints = [
    'I like how calm and caring she is.',
    'I like his confidence and ambition.',
    'I feel safe when I talk to her.',
    'There is strong attraction but also confusion.',
    'I do not like how distant they become sometimes.',
    'I like their smile, but I do not like their ego.',
    'I feel connected, but their mixed signals confuse me.',
    'I do not like his voice, but I like how he makes me laugh.',
  ];

  static const List<String> _fallbackPlaces = [
    'New Delhi, India',
    'Delhi, India',
    'Mumbai, Maharashtra, India',
    'Bengaluru, Karnataka, India',
    'Kolkata, West Bengal, India',
    'Chennai, Tamil Nadu, India',
    'Hyderabad, Telangana, India',
    'Pune, Maharashtra, India',
    'Ahmedabad, Gujarat, India',
    'Jaipur, Rajasthan, India',
    'Lucknow, Uttar Pradesh, India',
    'Kanpur, Uttar Pradesh, India',
    'Varanasi, Uttar Pradesh, India',
    'Prayagraj, Uttar Pradesh, India',
    'Indore, Madhya Pradesh, India',
    'Bhopal, Madhya Pradesh, India',
    'Gwalior, Madhya Pradesh, India',
    'Jabalpur, Madhya Pradesh, India',
    'Patna, Bihar, India',
    'Ranchi, Jharkhand, India',
    'Bhubaneswar, Odisha, India',
    'Guwahati, Assam, India',
    'Chandigarh, India',
    'Ludhiana, Punjab, India',
    'Amritsar, Punjab, India',
    'Dehradun, Uttarakhand, India',
    'Haridwar, Uttarakhand, India',
    'Shimla, Himachal Pradesh, India',
    'Jammu, Jammu and Kashmir, India',
    'Srinagar, Jammu and Kashmir, India',
    'Raipur, Chhattisgarh, India',
    'Nagpur, Maharashtra, India',
    'Nashik, Maharashtra, India',
    'Surat, Gujarat, India',
    'Vadodara, Gujarat, India',
    'Rajkot, Gujarat, India',
    'Udaipur, Rajasthan, India',
    'Jodhpur, Rajasthan, India',
    'Kota, Rajasthan, India',
    'Agra, Uttar Pradesh, India',
    'Meerut, Uttar Pradesh, India',
    'Noida, Uttar Pradesh, India',
    'Ghaziabad, Uttar Pradesh, India',
    'Gurugram, Haryana, India',
    'Faridabad, Haryana, India',
    'Mysuru, Karnataka, India',
    'Mangaluru, Karnataka, India',
    'Kochi, Kerala, India',
    'Thiruvananthapuram, Kerala, India',
    'Coimbatore, Tamil Nadu, India',
    'Madurai, Tamil Nadu, India',
    'Vijayawada, Andhra Pradesh, India',
    'Visakhapatnam, Andhra Pradesh, India',
    'Warangal, Telangana, India',
    'Dubai, United Arab Emirates',
    'Abu Dhabi, United Arab Emirates',
    'Doha, Qatar',
    'London, United Kingdom',
    'Manchester, United Kingdom',
    'Birmingham, United Kingdom',
    'New York, United States',
    'Los Angeles, United States',
    'Chicago, United States',
    'Houston, United States',
    'San Francisco, United States',
    'Toronto, Canada',
    'Vancouver, Canada',
    'Sydney, Australia',
    'Melbourne, Australia',
    'Singapore',
    'Bangkok, Thailand',
    'Kuala Lumpur, Malaysia',
    'Tokyo, Japan',
    'Osaka, Japan',
    'Seoul, South Korea',
    'Paris, France',
    'Berlin, Germany',
    'Munich, Germany',
    'Rome, Italy',
    'Milan, Italy',
    'Madrid, Spain',
    'Barcelona, Spain',
    'Amsterdam, Netherlands',
    'Zurich, Switzerland',
    'Geneva, Switzerland',
  ];

  @override
  void initState() {
    super.initState();

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_promptController.text.trim().isNotEmpty) return;

      setState(() {
        _hintIndex = (_hintIndex + 1) % _rotatingHints.length;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _nameController.dispose();
    _timeController.dispose();
    _placeController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF59E0B),
              surface: _matchPanel,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedDob = picked;
    });
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 6, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF59E0B),
              surface: _matchPanel,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: _matchPanel,
              hourMinuteTextColor: _matchWhite,
              dayPeriodTextColor: _matchWhite,
              dialHandColor: Color(0xFFF59E0B),
              dialBackgroundColor: _matchBlack,
              entryModeIconColor: _matchGold,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedTime = picked;
      _timeController.text = _formatTimeOfDay(picked);
    });
  }

  Future<void> _pickPlace() async {
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<BirthPlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlacePickerSheet(
        initialValue: _placeController.text.trim(),
        fallbackPlaces: _fallbackPlaces,
      ),
    );

    if (selected == null || selected.description.trim().isEmpty || !mounted) {
      return;
    }

    setState(() {
      _placeController.text = selected.description.trim();
      _selectedLatitude = selected.latitude;
      _selectedLongitude = selected.longitude;
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  void _submit() {
    final name = _nameController.text.trim();
    final time = _timeController.text.trim();
    final place = _placeController.text.trim();
    final prompt = _promptController.text.trim();

    if (name.isEmpty || _selectedDob == null || time.isEmpty || place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill partner name, DOB, time, and place.'),
          backgroundColor: _matchPanel,
        ),
      );
      return;
    }

    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tell Bhrigu what you like or dislike about them.'),
          backgroundColor: _matchPanel,
        ),
      );
      return;
    }

    widget.onSubmit(
      PartnerBirthProfile(
        name: name,
        dob: _selectedDob!,
        timeOfBirth: time,
        placeOfBirth: place,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        emotionalPrompt: prompt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dobText = _selectedDob == null
        ? 'Select date of birth'
        : '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}';

    final timeText = _timeController.text.trim().isEmpty
        ? 'Select time of birth'
        : _timeController.text.trim();

    final placeText = _placeController.text.trim().isEmpty
        ? 'Search place of birth'
        : _placeController.text.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partner Birth Details',
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select their birth blueprint and what your heart notices about them.',
            style: TextStyle(
              color: _matchMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _nameController,
            hint: 'Partner name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _pickerTile(
            text: dobText,
            empty: _selectedDob == null,
            icon: Icons.cake_outlined,
            onTap: widget.loading ? null : _pickDob,
          ),
          const SizedBox(height: 12),
          _pickerTile(
            text: timeText,
            empty: _timeController.text.trim().isEmpty,
            icon: Icons.access_time,
            onTap: widget.loading ? null : _pickTime,
          ),
          const SizedBox(height: 12),
          _pickerTile(
            text: placeText,
            empty: _placeController.text.trim().isEmpty,
            icon: Icons.location_on_outlined,
            onTap: widget.loading ? null : _pickPlace,
          ),
          const SizedBox(height: 14),
          const Text(
            'What do you like the most or least about them?',
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            enabled: !widget.loading,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              color: _matchWhite,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: _rotatingHints[_hintIndex],
              hintStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.45,
              ),
              filled: true,
              fillColor: _matchBlack.withAlpha(190),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps Bhrigu understand what your heart is responding to.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: widget.loading ? null : _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    _matchPanel,
                    _matchPanelSoft,
                  ],
                ),
                border: Border.all(
                  color: _matchGold.withAlpha(150),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _matchGold.withAlpha(70),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Reveal Compatibility',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required String text,
    required bool empty,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: _inputBox(),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFFD88A),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: empty ? Colors.white54 : _matchWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: _matchMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      enabled: !widget.loading,
      style: const TextStyle(
        color: _matchWhite,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFFFD88A),
          size: 20,
        ),
        filled: true,
        fillColor: _matchBlack.withAlpha(190),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
    );
  }

  BoxDecoration _box() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _matchPanelSoft,
          _matchPanel,
        ],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _matchGold.withAlpha(80)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(70),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  BoxDecoration _inputBox() {
    return BoxDecoration(
      color: _matchBlack.withAlpha(190),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _matchLine),
    );
  }
}

class _PlacePickerSheet extends StatefulWidget {
  final String initialValue;
  final List<String> fallbackPlaces;

  const _PlacePickerSheet({
    required this.initialValue,
    required this.fallbackPlaces,
  });

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: firebaseFunctionsRegion,
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final TextEditingController _searchController;

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<BirthPlaceSuggestion> _places = [];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(text: widget.initialValue);
    _places = _fallbackMatches(widget.initialValue);

    _searchController.addListener(_onSearchChanged);

    final initial = widget.initialValue.trim();
    if (initial.length >= 2) {
      _searchPlaces(initial);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _debounce?.cancel();

    if (query.length < 2) {
      setState(() {
        _loading = false;
        _error = null;
        _places = _fallbackMatches(query);
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _debounce = Timer(const Duration(milliseconds: 550), () {
      _searchPlaces(query);
    });
  }

  List<BirthPlaceSuggestion> _fallbackMatches(String query) {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return widget.fallbackPlaces
          .take(20)
          .map((place) => BirthPlaceSuggestion(description: place))
          .toList();
    }

    return widget.fallbackPlaces
        .where((place) => place.toLowerCase().contains(text))
        .take(20)
        .map((place) => BirthPlaceSuggestion(description: place))
        .toList();
  }

  Future<void> _searchPlaces(String query) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User not signed in');
      }

      final callable = _functions.httpsCallable('searchBirthPlaces');

      final response = await callable.call({
        'query': query,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final rawPlaces = data['places'];

      final rawPlaceDetails = data['placeDetails'];

      final results = rawPlaceDetails is List
          ? rawPlaceDetails
              .whereType<Map>()
              .map(
                (place) => BirthPlaceSuggestion.fromMap(
                  Map<String, dynamic>.from(place),
                ),
              )
              .where((place) => place.description.trim().isNotEmpty)
              .toList()
          : <BirthPlaceSuggestion>[];

      final legacyResults = rawPlaces is List
          ? rawPlaces
              .map((place) => place.toString().trim())
              .where((place) => place.isNotEmpty)
              .map((place) => BirthPlaceSuggestion(description: place))
              .toList()
          : <BirthPlaceSuggestion>[];

      final resolvedResults = results.isNotEmpty ? results : legacyResults;

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _loading = false;
        _error = null;
        _places =
            resolvedResults.isEmpty ? _fallbackMatches(query) : resolvedResults;
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'Birth place search FirebaseFunctionsException code: ${e.code}',
      );
      debugPrint(
        'Birth place search FirebaseFunctionsException message: ${e.message}',
      );
      debugPrint(
        'Birth place search FirebaseFunctionsException details: ${e.details}',
      );

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _loading = false;
        _error =
            'Online place search failed: ${e.code}. You can still use the typed place.';
        _places = _fallbackMatches(query);
      });
    } catch (e, stack) {
      debugPrint('Birth place search error: $e');
      debugPrint('Birth place search stack: $stack');

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _loading = false;
        _error = 'Could not search online. You can still use the typed place.';
        _places = _fallbackMatches(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typedValue = _searchController.text.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _matchBlack,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: _matchLine,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFFFD88A),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search Birth Place',
                        style: TextStyle(
                          color: Color(0xFFFFD88A),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(
                    color: _matchWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type city, town, district, or country',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFFFD88A),
                    ),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFD88A),
                              ),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: _matchPanelSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: _matchMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (typedValue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(
                      context,
                      BirthPlaceSuggestion(description: typedValue),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _matchPanelSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withAlpha(100),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_location_alt_outlined,
                            color: Color(0xFFFFD88A),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Use "$typedValue"',
                              style: const TextStyle(
                                color: _matchWhite,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _places.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Start typing a city, town, district, or country.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _matchMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                        itemCount: _places.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final place = _places[index];

                          return GestureDetector(
                            onTap: () => Navigator.pop(context, place),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: _matchPanelSoft,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _matchLine,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.place_outlined,
                                    color: Color(0xFFFFD88A),
                                    size: 19,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      place.description,
                                      style: const TextStyle(
                                        color: _matchWhite,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
