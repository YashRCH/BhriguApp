part of '../home_screen.dart';

extension _HomeScreenSections on _HomeScreenState {
  Widget _homeLoadingPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF020006),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF010004),
                  Color(0xFF05010D),
                  Color(0xFF0E031A),
                  Color(0xFF040008),
                ],
                stops: [0.0, 0.38, 0.72, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.18, -0.12),
                radius: 0.82,
                colors: [
                  const Color(0xFF2E0959).withValues(alpha: 0.36),
                  const Color(0xFF0C0314).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.46, 1.0],
              ),
            ),
          ),
          CustomPaint(
            painter: _CosmicLoadingBackgroundPainter(),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _plasmaController,
              builder: (context, child) => Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE040FB).withValues(alpha: 0.22),
                      blurRadius: 42,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: CustomPaint(
                    painter: _TeslaGlobePainter(_plasmaController.value),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeHeader(String name, String sunSign) {
    final displaySign = cleanZodiacSignName(sunSign);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _todayFormatted(),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6080),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_greeting()}, ',
                      style: GoogleFonts.cinzel(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFF0ECF8),
                      ),
                    ),
                    TextSpan(
                      text: name,
                      style: GoogleFonts.cinzel(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFC7A867),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1630),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2E2650),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFFB58E34),
                      size: 22,
                    ),
                  ),
                ),
                Positioned(
                  right: 50,
                  top: -4,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showCosmicBlueprintHint ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        width: 155,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1630),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFB58E34).withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'View your cosmic blueprint here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC7A867),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isKnownZodiacSign(displaySign)) ...[
              ZodiacSignIcon(
                sign: displaySign,
                size: 24,
                fallbackColor: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              displaySign,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFF59E0B),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.cinzelDecorative(
        fontSize: 12.5,
        color: const Color(0xFFC7A867), // Matches envelope lines perfectly
        letterSpacing: 3.0,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: const Color(0xFFC7A867).withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  Widget _horoscopeCard() {
    return GestureDetector(
      onTap: _revealHoroscope,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        // When locked, the envelope itself is the card. When revealed, _horoscopePremiumReading has its own background.
        // We only show the default card background when loading or error.
        decoration: (_horoscopeLoading || _horoscope == null)
            ? BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2E1065), Color(0xFF1A1630)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6B21A8), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : const BoxDecoration(), // Transparent for envelope/revealed states
        child: _horoscopeLoading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: OwlSpriteAnimator(
                    pose: OwlPose.writing,
                    size: 64,
                  ),
                ),
              )
            : _horoscope == null
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Could not load today\'s reading. Pull to refresh.',
                        style: TextStyle(color: Color(0xFF6B6080)),
                      ),
                    ),
                  )
                : _horoscopeRevealed
                    ? FadeTransition(
                        opacity: _envelopeFade,
                        child: _horoscopePremiumReading(),
                      )
                    : _envelopeLocked(),
      ),
    );
  }

  Widget _envelopeLocked() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 280,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF283149), // Deep muted medieval blue
                Color(0xFF1E243B),
                Color(0xFF15192C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFFC7A867).withValues(alpha: 0.1),
                blurRadius: 2,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _RealisticEnvelopePainter(),
                ),
              ),
              // Extracted Gold Seal Image positioned precisely at the flap junction
              Positioned(
                top: 72, // 160 * 0.65 (junction center = 104) - 32 (half of 64)
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Image.asset(
                      'assets/images/gold_seal.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'tap to open reading',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B6080),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _horoscopeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🌅', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text(
              'MORNING INSIGHT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _horoscope!['morning'] ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFFF0ECF8),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF2E2650)),
        const SizedBox(height: 16),
        const Row(
          children: [
            Text('🌙', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text(
              'EVENING REFLECTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9D6FE8),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _horoscope!['evening'] ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFFF0ECF8),
          ),
        ),
      ],
    );
  }

  Widget _horoscopePremiumReading() {
    final bhriguToday = _horoscopeText(
      'bhriguToday',
      fallback: _horoscopeText(
        'morning',
        fallback: 'Notice what keeps asking for your attention.',
      ),
    );
    final yourTransit = _horoscopeText(
      'yourTransit',
      fallback: _horoscopeText(
        'evening',
        fallback: 'Today asks for patience before reaction.',
      ),
    );
    final doText = _horoscopeText(
      'doText',
      fallback: _horoscopeJoinedList(
        'doLines',
        fallback: 'Choose one clean action and finish it before seeking signs.',
      ),
    );
    final avoidText = _horoscopeText(
      'avoidText',
      fallback: _horoscopeJoinedList(
        'avoidLines',
        fallback: 'Avoid turning silence into evidence, drama, or prophecy.',
      ),
    );
    final relationships = _horoscopeText(
      'relationships',
      fallback: 'Let consistency matter more than charm today.',
    );
    final workMoney = _horoscopeText(
      'workMoney',
      fallback: 'Small discipline brings more luck than big ambition.',
    );
    final innerWeather = _horoscopeText(
      'innerWeather',
      fallback: 'Calm outside does not always mean settled inside.',
    );
    final mantra = _horoscopeText(
      'mantra',
      fallback: 'Do not romanticize what costs your peace.',
    );
    final today = DateTime.now();
    final horoscopeContentId =
        'horoscope_${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final horoscopeReportText = [
      bhriguToday,
      yourTransit,
      doText,
      avoidText,
      relationships,
      workMoney,
      innerWeather,
      mantra,
    ].where((text) => text.trim().isNotEmpty).join('\n\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1430),
            Color(0xFF0F0A18),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC7A867).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _horoscopeHook(bhriguToday),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF2E2650)),
          const SizedBox(height: 20),
          _horoscopeTransit(yourTransit),
          const SizedBox(height: 24),
          _horoscopeActionParagraphCards(
            doText: doText,
            avoidText: avoidText,
          ),
          const SizedBox(height: 24),
          _horoscopeLifeArea(
            label: 'RELATIONSHIPS',
            text: relationships,
          ),
          _horoscopeLifeArea(
            label: 'WORK / MONEY',
            text: workMoney,
          ),
          _horoscopeLifeArea(
            label: 'INNER WEATHER',
            text: innerWeather,
            bottomGap: 0,
          ),
          const SizedBox(height: 24),
          _horoscopeMantra(mantra),
          Align(
            alignment: Alignment.centerRight,
            child: AiReportButton(
              feature: 'horoscope',
              contentId: horoscopeContentId,
              contentText: horoscopeReportText,
              label: 'Report',
            ),
          ),
        ],
      ),
    );
  }

  Widget _horoscopeHook(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'BHRIGU TODAY',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: const Color(0xFF6B6080),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontStyle: FontStyle.italic,
            height: 1.4,
            color: const Color(0xFFE5D5F5),
          ),
        ),
      ],
    );
  }

  Widget _horoscopeTransit(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR TRANSIT',
          style: GoogleFonts.cinzel(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFC7A867),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: const Color(0xFFB8AEE0),
          ),
        ),
      ],
    );
  }

  Widget _horoscopeActionParagraphCards({
    required String doText,
    required String avoidText,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackCards = constraints.maxWidth < 330;
        final doCard = _horoscopeActionParagraphCard(
          label: 'DO',
          text: doText,
          accent: const Color(0xFFE8B530),
          textColor: const Color(0xFFE5D5F5),
        );
        final avoidCard = _horoscopeActionParagraphCard(
          label: 'AVOID',
          text: avoidText,
          accent: const Color(0xFFE040FB),
          textColor: const Color(0xFFD8B4E2),
        );

        if (stackCards) {
          return Column(
            children: [
              doCard,
              const SizedBox(height: 12),
              avoidCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: doCard),
            const SizedBox(width: 12),
            Expanded(child: avoidCard),
          ],
        );
      },
    );
  }

  Widget _horoscopeActionParagraphCard({
    required String label,
    required String text,
    required Color accent,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050408).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 16,
              height: 1.42,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _horoscopeActionCards({
    required List<String> doLines,
    required List<String> avoidLines,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackCards = constraints.maxWidth < 330;
        final doCard = _horoscopeActionCard(
          label: 'DO',
          lines: doLines,
          accent: const Color(0xFFE8B530),
          bullet: '✦',
          textColor: const Color(0xFFE5D5F5),
        );
        final avoidCard = _horoscopeActionCard(
          label: 'AVOID',
          lines: avoidLines,
          accent: const Color(0xFFE040FB),
          bullet: '◌',
          textColor: const Color(0xFFD8B4E2),
        );

        if (stackCards) {
          return Column(
            children: [
              doCard,
              const SizedBox(height: 12),
              avoidCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: doCard),
            const SizedBox(width: 12),
            Expanded(child: avoidCard),
          ],
        );
      },
    );
  }

  Widget _horoscopeActionCard({
    required String label,
    required List<String> lines,
    required Color accent,
    required String bullet,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050408).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bullet,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 16,
                        height: 1.35,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _horoscopeText(String key, {String fallback = ''}) {
    final value = (_horoscope?[key] as String? ?? '').trim();
    return value.isEmpty ? fallback : value;
  }

  // ignore: unused_element
  List<String> _horoscopeList(
    String key, {
    required List<String> fallback,
  }) {
    final value = _horoscope?[key];

    if (value is List) {
      final lines = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) return lines;
    }

    return fallback;
  }

  String _horoscopeJoinedList(String key, {required String fallback}) {
    final value = _horoscope?[key];

    if (value is List) {
      final lines = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) return lines.join(' ');
    }

    return fallback;
  }

  Widget _horoscopeLifeArea({
    required String label,
    required String text,
    double bottomGap = 20,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: const Color(0xFF6B6080),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 2,
                height: 44,
                margin: const EdgeInsets.only(top: 4, right: 14),
                color: const Color(0xFFC7A867).withValues(alpha: 0.4),
              ),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 18,
                    height: 1.5,
                    color: const Color(0xFFD4D4CE),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _horoscopeMantra(String mantra) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF050408).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF9D6FE8).withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B530).withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MANTRA',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 10,
              letterSpacing: 4,
              color: const Color(0xFF9D6FE8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            mantra,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.35,
              color: const Color(0xFFE8B530),
              shadows: [
                Shadow(
                  color: const Color(0xFFE8B530).withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _horoscopeReadingSection({
    required String label,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF130D1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E1A4A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 38,
            margin: const EdgeInsets.only(top: 4, right: 14),
            color: const Color(0xFF8A6B22).withValues(alpha: 0.62),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB58E34),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _horoscopeLineList(List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line,
            style: const TextStyle(
              fontSize: 14,
              height: 1.42,
              color: Color(0xFFD4D4CE),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ignore: unused_element
  Widget _horoscopeBodyText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Color(0xFFD4D4CE),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _moonPhaseCard({
    required MoonPhaseInfo moonPhaseInfo,
    required String subtitle,
  }) {
    return _cosmicStatusCard(
      label: 'MOON PHASE',
      mainIcon: moonPhaseInfo.icon,
      title: moonPhaseInfo.name,
      subtitle: subtitle,
      orbAccent: const Color(0xFF9D6FE8),
      titleColor: const Color(0xFFF0ECF8),
      isMoonCard: true,
    );
  }

  Widget _dailyEnergyCard(
    DailyEnergyInfo energy, {
    required String subtitle,
  }) {
    final symbol = energy.symbol;
    final planet = energy.planet;

    return _cosmicStatusCard(
      label: 'DAILY ENERGY',
      mainIcon: symbol,
      planetAssetName: planet,
      title: planet,
      subtitle: subtitle,
      orbAccent: const Color(0xFFF59E0B),
      titleColor: const Color(0xFFF59E0B),
      isMoonCard: false,
    );
  }

  Widget _cosmicStatusCard({
    required String label,
    required String mainIcon,
    String? planetAssetName,
    required String title,
    required String subtitle,
    required Color orbAccent,
    required Color titleColor,
    required bool isMoonCard,
  }) {
    final titleWords = title.trim().split(RegExp(r'\s+'));

    Widget titleWidget;

    if (isMoonCard) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: titleWords.map((word) {
          return Text(
            word,
            style: TextStyle(
              fontSize: 14,
              color: titleColor,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        }).toList(),
      );
    } else {
      titleWidget = FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: titleColor,
            height: 1.18,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 178),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1630),
            const Color(0xFF171228).withValues(alpha: 0.92),
            const Color(0xFF0D0B1E).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2650)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _plasmaController,
        builder: (context, child) {
          final pulse = isMoonCard
              ? 0.55
              : 0.55 + math.sin(_plasmaController.value * math.pi * 2) * 0.18;

          final glowOpacity = (0.16 + pulse * 0.18).clamp(0.0, 1.0);
          final softOpacity = (0.08 + pulse * 0.08).clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B6080),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B0F19),
                      border: Border.all(
                        color: orbAccent.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: orbAccent.withValues(alpha: glowOpacity),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFFC7A867)
                              .withValues(alpha: softOpacity),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isMoonCard
                          ? _MoonPhaseAsset(
                              phaseIcon: mainIcon,
                            )
                          : PlanetAsset(
                              planetName: planetAssetName ?? title,
                              size: 34,
                              fallback: Text(
                                mainIcon,
                                style: const TextStyle(fontSize: 25),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: titleWidget,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B1E).withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFB58E34).withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFC7A867),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                  softWrap: true,
                  maxLines: 6,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _angelNumberCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2650)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'ANGEL NUMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B6080),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _angelNumber['number']!,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE5D5F5), // Moonlight silver
              height: 1,
              shadows: [
                Shadow(
                  color: Color(0xFFE5D5F5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              _angelNumber['meaning']!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFF0ECF8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bhriguCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E2650)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ASK BHRIGU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B6080),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _askBhrigu,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB58E34)
                        .withValues(alpha: _bhriguGlowing ? 0.6 : 0.0),
                    blurRadius: _bhriguGlowing ? 30 : 0,
                    spreadRadius: _bhriguGlowing ? 8 : 0,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _plasmaController,
                builder: (context, child) => CustomPaint(
                  painter: _TeslaGlobePainter(_plasmaController.value),
                ),
              ),
            ),
          ),
          const Spacer(),
          _bhriguAnswer.isEmpty
              ? const Text(
                  'TAP TO ASK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B6080),
                    letterSpacing: 1,
                  ),
                )
              : Text(
                  _bhriguAnswer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE5D5F5),
                  ),
                ),
        ],
      ),
    );
  }

}
