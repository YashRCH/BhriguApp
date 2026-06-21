import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/monetization_constants.dart';
import '../models/monetization_status.dart';
import '../services/monetization_service.dart';

enum _PlusPlanKind { monthly, yearly }

class MonetizationPaywallPreview extends StatefulWidget {
  const MonetizationPaywallPreview({
    super.key,
    required this.service,
    this.onStatusChanged,
  });

  final MonetizationService service;
  final ValueChanged<MonetizationStatus>? onStatusChanged;

  @override
  State<MonetizationPaywallPreview> createState() =>
      _MonetizationPaywallPreviewState();
}

class _MonetizationPaywallPreviewState
    extends State<MonetizationPaywallPreview> {
  late Future<_MonetizationPanelData> _future;

  String? _purchasingKey;
  bool _restoring = false;
  bool _openingManageLink = false;
  DateTime? _dakshanaPurchasePendingUntil;
  String? _secureSyncErrorMessage;

  static const _gold = Color(0xFFB58E34);
  static const _softGold = Color(0xFFC7A867);
  static const _panel = Color(0xFF1A1630);
  static const _panelDark = Color(0xFF151126);
  static const _ink = Color(0xFFE5D5F5);
  static const _muted = Color(0xFF8E83A8);
  static const _dim = Color(0xFF6B6080);
  static const _border = Color(0xFF3A2D50);

  @override
  void initState() {
    super.initState();
    _future = _load(syncSecure: true);
  }

  Future<_MonetizationPanelData> _load({bool syncSecure = false}) async {
    MonetizationStatus? syncedStatus;
    try {
      if (syncSecure) {
        syncedStatus = await _syncSecureOrStatus();
      }

      final results = await Future.wait<dynamic>([
        syncedStatus != null
            ? Future<MonetizationStatus>.value(syncedStatus)
            : widget.service.status(),
        widget.service.offerings(),
        widget.service.customerInfo(),
      ]);

      final data = _MonetizationPanelData(
        status: results[0] as MonetizationStatus,
        offerings: results[1] as Offerings?,
        customerInfo: results[2] as CustomerInfo?,
      );
      if (mounted) {
        widget.onStatusChanged?.call(data.status);
      }
      return data;
    } catch (_) {
      const data = _MonetizationPanelData(
        status: MonetizationStatus.unavailable(),
        offerings: null,
        customerInfo: null,
      );
      if (mounted) {
        widget.onStatusChanged?.call(data.status);
      }
      return data;
    }
  }

  Future<MonetizationStatus> _syncSecureOrStatus() async {
    try {
      final status = await widget.service.syncRevenueCatPurchases();
      _setSecureSyncError(null);
      return status;
    } catch (error) {
      _setSecureSyncError(_friendlyError(error));
      return widget.service.status();
    }
  }

  void _setSecureSyncError(String? message) {
    if (_secureSyncErrorMessage == message) return;
    if (!mounted) {
      _secureSyncErrorMessage = message;
      return;
    }

    setState(() {
      _secureSyncErrorMessage = message;
    });
  }

  void _refresh({bool syncSecure = false}) {
    setState(() {
      _future = _load(syncSecure: syncSecure);
    });
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;

    setState(() {
      _restoring = true;
    });

    try {
      final customerInfo = await widget.service.restorePurchasesInfo();
      final restored = customerInfo != null;
      final plusInRevenueCat = _plusActiveInRevenueCat(customerInfo);
      final syncedStatus = restored
          ? await _waitForSecureSync(
              expectPlus: plusInRevenueCat,
              expectDakshana: false,
            )
          : null;
      if (!mounted) return;

      _showSnack(
        syncedStatus?.plusActive == true
            ? '${_planLabel(syncedStatus!.plan)} Plus restored and active.'
            : plusInRevenueCat
                ? _secureSyncPendingMessage(purchaseCompleted: false)
                : restored
                    ? 'Restore checked. No active plan found.'
                    : 'Purchases are not available in this build yet.',
      );
      _refresh(syncSecure: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not restore purchases: ${_friendlyError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
        });
      }
    }
  }

  Future<void> _purchase(
    Package package, {
    _PlusPlanKind? plusPlan,
  }) async {
    final key = _packageKey(package);
    if (_purchasingKey != null) return;

    setState(() {
      _purchasingKey = key;
    });

    try {
      final customerInfo = await widget.service.purchasePackageInfo(package);
      final completed = customerInfo != null;
      if (!mounted) return;

      final isPlusPurchase = _matchesProductId(
            package.storeProduct.identifier,
            bhriguPlusProductId,
          ) ||
          _plusActiveInRevenueCat(customerInfo);
      final isDakshanaPurchase =
          _matchesProductId(package.storeProduct.identifier, dakshanaProductId);
      if (completed && isDakshanaPurchase) {
        setState(() {
          _dakshanaPurchasePendingUntil = DateTime.now().add(
            const Duration(minutes: 2),
          );
        });
      }

      final syncedStatus = completed
          ? await _waitForSecureSync(
              expectPlus: isPlusPurchase,
              expectedPlusPlan: isPlusPurchase ? plusPlan : null,
              expectDakshana: isDakshanaPurchase,
            )
          : null;
      if (!mounted) return;

      _showSnack(
        completed
            ? _purchaseResultMessage(
                status: syncedStatus,
                expectPlus: isPlusPurchase,
                expectedPlusPlan: isPlusPurchase ? plusPlan : null,
                expectDakshana: isDakshanaPurchase,
              )
            : 'Purchases are not available in this build yet.',
      );
      _refresh(syncSecure: true);
    } on PlatformException catch (e) {
      if (!mounted || _isPurchaseCancelled(e)) return;
      _showSnack('Could not complete purchase: ${_friendlyError(e)}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not complete purchase: ${_friendlyError(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _purchasingKey = null;
        });
      }
    }
  }

  Future<void> _openManageSubscriptions() async {
    if (_openingManageLink) return;

    setState(() {
      _openingManageLink = true;
    });

    try {
      final url = widget.service.manageSubscriptionUri();
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (!opened) {
        _showSnack('Could not open Google Play subscriptions.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingManageLink = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MonetizationPanelData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _shell(
            child: const SizedBox(
              height: 138,
              child: Center(
                child: CircularProgressIndicator(
                  color: _gold,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final status = data.status;
        final defaultOffering =
            data.offerings?.getOffering('default') ?? data.offerings?.current;
        final dakshanaOffering = data.offerings?.getOffering('dakshana');
        final monthly = _packageForPlusPlan(
          defaultOffering,
          data.offerings,
          _PlusPlanKind.monthly,
        );
        Package? yearly = _packageForPlusPlan(
          defaultOffering,
          data.offerings,
          _PlusPlanKind.yearly,
        );
        if (monthly != null &&
            yearly != null &&
            _packageKey(monthly) == _packageKey(yearly)) {
          yearly = null;
        }
        final dakshana = _packageForProduct(
              dakshanaOffering,
              dakshanaProductId,
            ) ??
            _packageForProductInOfferings(data.offerings, dakshanaProductId);
        final plusInRevenueCat = _plusActiveInRevenueCat(data.customerInfo);
        final dakshanaSyncPending = _dakshanaSyncPending(status);
        final hasLiveProducts =
            monthly != null || yearly != null || dakshana != null;
        final activePlusPlan =
            status.plusActive ? _planKindForStatus(status.plan) : null;
        final plusSyncPending = !status.plusActive && plusInRevenueCat;
        final unknownPlusActive = status.plusActive && activePlusPlan == null;
        final monthlyDisabled = plusSyncPending ||
            unknownPlusActive ||
            activePlusPlan == _PlusPlanKind.monthly ||
            activePlusPlan == _PlusPlanKind.yearly;
        final yearlyDisabled = plusSyncPending ||
            unknownPlusActive ||
            activePlusPlan == _PlusPlanKind.yearly;
        final monthlyDisabledLabel = plusSyncPending
            ? 'Updating'
            : unknownPlusActive
                ? 'Active'
                : activePlusPlan == _PlusPlanKind.yearly
                    ? 'Included'
                    : 'Current';
        final yearlyDisabledLabel = plusSyncPending
            ? 'Updating'
            : unknownPlusActive
                ? 'Active'
                : 'Current';

        return _shell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(status, data.customerInfo),
              if (!status.plusActive && plusInRevenueCat) ...[
                const SizedBox(height: 12),
                _backendSyncNotice(detail: _secureSyncErrorMessage),
              ],
              if (!hasLiveProducts) ...[
                const SizedBox(height: 14),
                _syncNotice(),
              ],
              const SizedBox(height: 16),
              _planRow(
                title: 'Bhrigu Plus Monthly',
                subtitle:
                    '50 messages, 20 tarot readings, 20 geomancy readings. Manual matches unlocked.',
                price: _price(monthly, 'INR 129 / USD 11.00'),
                package: monthly,
                plusPlan: _PlusPlanKind.monthly,
                disabled: monthlyDisabled,
                disabledLabel: monthlyDisabledLabel,
              ),
              const _DividerLine(),
              _planRow(
                title: 'Bhrigu Plus Yearly',
                subtitle: 'Unlimited messages, readings, and manual matches.',
                price: _price(yearly, 'INR 1111 / USD 111.00'),
                package: yearly,
                plusPlan: _PlusPlanKind.yearly,
                disabled: yearlyDisabled,
                disabledLabel: yearlyDisabledLabel,
              ),
              const _DividerLine(),
              _planRow(
                title: 'Dakshana Pack',
                subtitle:
                    '5 chat messages, 1 tarot reading, 1 geomancy reading. One pack can be active at a time.',
                price: _price(dakshana, 'INR 49 / USD 2.00'),
                package: dakshana,
                disabled: !status.canBuyDakshana || dakshanaSyncPending,
                disabledLabel: dakshanaSyncPending ? 'Updating' : 'Current',
              ),
              const SizedBox(height: 16),
              _actions(),
              const SizedBox(height: 10),
              Text(
                _enforcementCopy(status),
                style: const TextStyle(
                  color: _dim,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_panel, _panelDark],
        ),
      ),
      child: child,
    );
  }

  Widget _header(MonetizationStatus status, CustomerInfo? customerInfo) {
    final plusInRevenueCat = _plusActiveInRevenueCat(customerInfo);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your plan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status.plusActive
                    ? 'Your plan is active. You can manage or restore anytime.'
                    : plusInRevenueCat
                        ? 'Your purchase is confirmed. We are updating your access.'
                        : status.dakshana.totalCredits > 0
                            ? '${status.dakshana.totalCredits} Dakshana credits available.'
                            : 'Pick Plus for regular guidance, or Dakshana for a small pack.',
                style: const TextStyle(
                  fontSize: 12,
                  color: _muted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh plans',
          onPressed: () => _refresh(syncSecure: true),
          icon: const Icon(Icons.refresh_rounded),
          color: _softGold,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _syncNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18).withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 17,
            color: _softGold,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Plans are still loading. Cards stay visible, and purchase buttons appear when Google Play returns options.',
              style: TextStyle(
                color: _muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backendSyncNotice({String? detail}) {
    final message = detail != null && detail.trim().isNotEmpty
        ? 'Your purchase is confirmed, but we could not update your access yet. Tap Restore or Refresh and try again in a moment.'
        : 'Your purchase is confirmed. We are updating your access. Tap Restore or Refresh if it does not appear soon.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171123).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            size: 17,
            color: _softGold,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<MonetizationStatus> _waitForSecureSync({
    required bool expectPlus,
    _PlusPlanKind? expectedPlusPlan,
    required bool expectDakshana,
  }) async {
    var latest = await _syncSecureOrStatus();
    if (_secureAccessSynced(
      latest,
      expectPlus: expectPlus,
      expectedPlusPlan: expectedPlusPlan,
      expectDakshana: expectDakshana,
    )) {
      return latest;
    }

    const retryDelays = [
      Duration(milliseconds: 450),
      Duration(milliseconds: 850),
      Duration(milliseconds: 1400),
      Duration(milliseconds: 2200),
      Duration(milliseconds: 3200),
    ];

    for (final delay in retryDelays) {
      await Future<void>.delayed(delay);
      if (!mounted) return latest;

      latest = await _syncSecureOrStatus();
      if (_secureAccessSynced(
        latest,
        expectPlus: expectPlus,
        expectedPlusPlan: expectedPlusPlan,
        expectDakshana: expectDakshana,
      )) {
        return latest;
      }
    }

    return latest;
  }

  bool _secureAccessSynced(
    MonetizationStatus status, {
    required bool expectPlus,
    _PlusPlanKind? expectedPlusPlan,
    required bool expectDakshana,
  }) {
    final plusSynced = !expectPlus ||
        (status.plusActive &&
            (expectedPlusPlan == null ||
                _planKindForStatus(status.plan) == expectedPlusPlan));
    final dakshanaSynced = !expectDakshana || status.dakshana.totalCredits > 0;
    return plusSynced && dakshanaSynced;
  }

  String _purchaseResultMessage({
    required MonetizationStatus? status,
    required bool expectPlus,
    _PlusPlanKind? expectedPlusPlan,
    required bool expectDakshana,
  }) {
    if (status != null &&
        _secureAccessSynced(
          status,
          expectPlus: expectPlus,
          expectedPlusPlan: expectedPlusPlan,
          expectDakshana: expectDakshana,
        )) {
      if (expectPlus) {
        return '${_planLabel(status.plan)} Plus is active now.';
      }

      if (expectDakshana) {
        return 'Dakshana is active now with ${status.dakshana.totalCredits} credits.';
      }
    }

    return _secureSyncPendingMessage();
  }

  String _secureSyncPendingMessage({bool purchaseCompleted = true}) {
    final prefix = purchaseCompleted
        ? 'Purchase completed in Google Play.'
        : 'Plus is active in Google Play.';
    return '$prefix We are updating your access. Tap Restore if it does not appear soon.';
  }

  Widget _planRow({
    required String title,
    required String subtitle,
    required String price,
    required Package? package,
    _PlusPlanKind? plusPlan,
    required bool disabled,
    required String disabledLabel,
  }) {
    final pending = package == null;
    final purchasing =
        package != null && _purchasingKey == _packageKey(package);
    final canTap = !pending && !disabled && _purchasingKey == null;
    final actionLabel = pending
        ? 'Loading'
        : disabled
            ? disabledLabel
            : 'Choose';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  price,
                  style: TextStyle(
                    color: pending ? _dim : _softGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 98,
            child: ElevatedButton(
              onPressed:
                  canTap ? () => _purchase(package, plusPlan: plusPlan) : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF050408),
                disabledBackgroundColor:
                    const Color(0xFF2E2650).withValues(alpha: 0.78),
                disabledForegroundColor: _dim,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: purchasing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Color(0xFF050408),
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      actionLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _secondaryButton(
          icon: Icons.restore_rounded,
          label: _restoring ? 'Checking' : 'Restore',
          onPressed: _restoring ? null : _restorePurchases,
        ),
        _secondaryButton(
          icon: Icons.open_in_new_rounded,
          label: _openingManageLink ? 'Opening' : 'Manage',
          onPressed: _openingManageLink ? null : _openManageSubscriptions,
        ),
      ],
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _softGold,
        disabledForegroundColor: _dim,
        side: BorderSide(color: _gold.withValues(alpha: 0.34)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _panel,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _price(Package? package, String fallback) {
    final price = package?.storeProduct.priceString.trim();
    if (price == null || price.isEmpty) return fallback;
    return price;
  }

  String _packageKey(Package package) {
    return '${package.presentedOfferingContext.offeringIdentifier}:'
        '${package.identifier}:${package.storeProduct.identifier}';
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      return 'We could not update your plan right now. Please try again in a moment.';
    }

    if (error is PlatformException) {
      final text = error.message?.trim().isNotEmpty == true
          ? error.message!
          : error.code;
      return _truncateErrorText(text);
    }
    return 'Please try again in a moment.';
  }

  static String _truncateErrorText(String value) {
    final text = value.trim();
    if (text.length <= 180) return text;
    return '${text.substring(0, 177)}...';
  }

  bool _isPurchaseCancelled(PlatformException error) {
    try {
      return PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError;
    } catch (_) {
      return error.code.toLowerCase().contains('cancel');
    }
  }

  static Package? _packageForProduct(Offering? offering, String productId) {
    if (offering == null || offering.availablePackages.isEmpty) return null;

    for (final package in offering.availablePackages) {
      if (_matchesProductId(package.storeProduct.identifier, productId)) {
        return package;
      }
    }

    return null;
  }

  static Package? _packageForPlusPlan(
    Offering? primaryOffering,
    Offerings? offerings,
    _PlusPlanKind plan,
  ) {
    final primaryMatch = _packageForPlusPlanInOffering(primaryOffering, plan);
    if (primaryMatch != null) return primaryMatch;

    if (offerings == null) return null;

    for (final offering in offerings.all.values) {
      final package = _packageForPlusPlanInOffering(offering, plan);
      if (package != null) return package;
    }

    return null;
  }

  static Package? _packageForPlusPlanInOffering(
    Offering? offering,
    _PlusPlanKind plan,
  ) {
    if (offering == null || offering.availablePackages.isEmpty) return null;

    for (final package in offering.availablePackages) {
      if (_isPlusPackage(package) && _packageLooksLikePlan(package, plan)) {
        return package;
      }
    }

    return null;
  }

  static bool _isPlusPackage(Package package) {
    return _matchesProductId(
            package.storeProduct.identifier, bhriguPlusProductId) ||
        _packageSignature(package).contains(bhriguPlusProductId);
  }

  static bool _packageLooksLikePlan(Package package, _PlusPlanKind plan) {
    final signature = _packageSignature(package);
    final hasYearlySignal = _containsAny(signature, const [
      'annual',
      'annually',
      'yearly',
      'year',
      'p1y',
      'p12m',
      '1y',
      '12m',
      '12month',
      '12 month',
      '12 months',
    ]);
    final hasMonthlySignal = _containsAny(signature, const [
      'monthly',
      'month',
      'p1m',
      '1m',
      '1 month',
    ]);

    switch (plan) {
      case _PlusPlanKind.yearly:
        return hasYearlySignal;
      case _PlusPlanKind.monthly:
        return hasMonthlySignal && !hasYearlySignal;
    }
  }

  static String _packageSignature(Package package) {
    return [
      package.identifier,
      package.packageType.toString(),
      package.storeProduct.identifier,
      package.presentedOfferingContext.offeringIdentifier,
    ]
        .map((value) => value.toString().trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static bool _containsAny(String text, List<String> needles) {
    final normalized = _normalizeSignalText(text);
    final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
    final tokenSet = tokens.toSet();
    final compact = normalized.replaceAll(' ', '');

    return needles.any((needle) {
      final normalizedNeedle = _normalizeSignalText(needle);
      if (normalizedNeedle.isEmpty) return false;

      final compactNeedle = normalizedNeedle.replaceAll(' ', '');
      final compactNeedleCanBeEmbedded = RegExp(r'\d').hasMatch(compactNeedle);
      if (normalizedNeedle.contains(' ')) {
        return normalized == normalizedNeedle ||
            normalized.contains(' $normalizedNeedle ') ||
            (compactNeedleCanBeEmbedded && compact.contains(compactNeedle));
      }

      return tokenSet.contains(normalizedNeedle) ||
          compact == compactNeedle ||
          (compactNeedleCanBeEmbedded && compact.contains(compactNeedle));
    });
  }

  static String _normalizeSignalText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static Package? _packageForProductInOfferings(
    Offerings? offerings,
    String productId,
  ) {
    if (offerings == null) return null;

    for (final offering in offerings.all.values) {
      final package = _exactPackageForProduct(offering, productId);
      if (package != null) return package;
    }

    return null;
  }

  static Package? _exactPackageForProduct(Offering offering, String productId) {
    for (final package in offering.availablePackages) {
      if (_matchesProductId(package.storeProduct.identifier, productId)) {
        return package;
      }
    }

    return null;
  }

  static bool _matchesProductId(String candidate, String productId) {
    final normalized = candidate.trim().split(':').first;
    return candidate == productId || normalized == productId;
  }

  static bool _plusActiveInRevenueCat(CustomerInfo? customerInfo) {
    return customerInfo?.entitlements.active
            .containsKey(bhriguPlusEntitlementId) ??
        false;
  }

  bool _dakshanaSyncPending(MonetizationStatus status) {
    final pendingUntil = _dakshanaPurchasePendingUntil;
    return status.canBuyDakshana &&
        pendingUntil != null &&
        DateTime.now().isBefore(pendingUntil);
  }

  static _PlusPlanKind? _planKindForStatus(String plan) {
    switch (plan.trim().toLowerCase()) {
      case 'monthly':
        return _PlusPlanKind.monthly;
      case 'yearly':
      case 'annual':
        return _PlusPlanKind.yearly;
      default:
        return null;
    }
  }

  static String _planLabel(String plan) {
    switch (plan.trim().toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'yearly':
      case 'annual':
        return 'Yearly';
      default:
        return 'Free';
    }
  }

  static String _enforcementCopy(MonetizationStatus status) {
    switch (status.mode.trim().toLowerCase()) {
      case 'enforce':
      case 'enforced':
      case 'on':
        return 'Subscriptions are managed by Google Play. Cancel anytime; access remains until the paid period ends.';
      case 'audit':
      case 'meter':
        return 'Purchases are being prepared. Your free allowance still works.';
      case 'unavailable':
        return 'We could not check your plan right now. Try Refresh or Restore.';
      default:
        return 'Purchases are not available in this build.';
    }
  }
}

class _MonetizationPanelData {
  const _MonetizationPanelData({
    required this.status,
    required this.offerings,
    required this.customerInfo,
  });

  final MonetizationStatus status;
  final Offerings? offerings;
  final CustomerInfo? customerInfo;
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: const Color(0xFF3A2D50).withValues(alpha: 0.58),
    );
  }
}
