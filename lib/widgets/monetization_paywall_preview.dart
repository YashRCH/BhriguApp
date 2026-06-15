import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/monetization_constants.dart';
import '../models/monetization_status.dart';
import '../services/monetization_service.dart';

class MonetizationPaywallPreview extends StatefulWidget {
  const MonetizationPaywallPreview({
    super.key,
    required this.service,
  });

  final MonetizationService service;

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
    _future = _load();
  }

  Future<_MonetizationPanelData> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.service.status(),
        widget.service.offerings(),
        widget.service.customerInfo(),
      ]);

      return _MonetizationPanelData(
        status: results[0] as MonetizationStatus,
        offerings: results[1] as Offerings?,
        customerInfo: results[2] as CustomerInfo?,
      );
    } catch (_) {
      return const _MonetizationPanelData(
        status: MonetizationStatus.free(),
        offerings: null,
        customerInfo: null,
      );
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;

    setState(() {
      _restoring = true;
    });

    try {
      final restored = await widget.service.restorePurchases();
      if (!mounted) return;

      _showSnack(
        restored
            ? 'Restore checked. Entitlements may take a moment to sync.'
            : 'Billing is not configured for this build yet.',
      );
      _refresh();
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

  Future<void> _purchase(Package package) async {
    final key = _packageKey(package);
    if (_purchasingKey != null) return;

    setState(() {
      _purchasingKey = key;
    });

    try {
      final completed = await widget.service.purchasePackage(package);
      if (!mounted) return;

      if (completed &&
          _matchesProductId(
              package.storeProduct.identifier, dakshanaProductId)) {
        setState(() {
          _dakshanaPurchasePendingUntil = DateTime.now().add(
            const Duration(minutes: 2),
          );
        });
      }

      _showSnack(
        completed
            ? 'Purchase completed. Access may take a moment to sync.'
            : 'Billing is not configured for this build yet.',
      );
      _refresh();
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
        final monthly = defaultOffering?.monthly;
        final yearly = defaultOffering?.annual;
        final dakshana = _packageForProduct(
              dakshanaOffering,
              dakshanaProductId,
            ) ??
            _packageForProductInOfferings(data.offerings, dakshanaProductId);
        final plusInRevenueCat = _plusActiveInRevenueCat(data.customerInfo);
        final dakshanaSyncPending = _dakshanaSyncPending(status);
        final hasLiveProducts =
            monthly != null || yearly != null || dakshana != null;

        return _shell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(status, data.customerInfo),
              const SizedBox(height: 14),
              _statusStrip(status, data.customerInfo),
              if (!hasLiveProducts) ...[
                const SizedBox(height: 14),
                _syncNotice(),
              ],
              const SizedBox(height: 16),
              _planRow(
                icon: Icons.auto_awesome_rounded,
                title: 'Bhrigu Plus Monthly',
                subtitle: '50 chats, 20 tarot, 20 geomancy each month.',
                price: _price(monthly, 'INR 129 / USD 11.00'),
                package: monthly,
                disabled: status.plusActive || plusInRevenueCat,
                disabledLabel: status.plusActive ? 'Active' : 'Syncing',
              ),
              const _DividerLine(),
              _planRow(
                icon: Icons.workspace_premium_rounded,
                title: 'Bhrigu Plus Yearly',
                subtitle: 'User-facing unlimited readings. Unlocks everything.',
                price: _price(yearly, 'INR 1111 / USD 111.00'),
                package: yearly,
                disabled: status.plusActive || plusInRevenueCat,
                disabledLabel: status.plusActive ? 'Active' : 'Syncing',
              ),
              const _DividerLine(),
              _planRow(
                icon: Icons.local_fire_department_rounded,
                title: '1 Dakshana',
                subtitle: '5 chats, 1 tarot, 1 geomancy. One active pack.',
                price: _price(dakshana, 'INR 49 / USD 2.00'),
                package: dakshana,
                disabled: !status.canBuyDakshana || dakshanaSyncPending,
                disabledLabel:
                    dakshanaSyncPending ? 'Syncing' : 'Use current pack',
              ),
              const SizedBox(height: 16),
              _actions(),
              const SizedBox(height: 10),
              const Text(
                'No enforcement is active in this build. Existing features stay available while billing is tested.',
                style: TextStyle(
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0A18).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _gold.withValues(alpha: 0.42)),
          ),
          child: const Icon(
            Icons.stars_rounded,
            color: _softGold,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.plusActive ? 'Bhrigu Plus' : 'Free Tier',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status.plusActive
                    ? '${_planLabel(status.plan)} access synced from Play.'
                    : plusInRevenueCat
                        ? 'Purchase seen by RevenueCat. Backend sync pending.'
                        : 'Plans are ready for purchase testing.',
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
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          color: _softGold,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _statusStrip(MonetizationStatus status, CustomerInfo? customerInfo) {
    final plusInRevenueCat = _plusActiveInRevenueCat(customerInfo);
    final chips = <Widget>[
      _metricChip('Mode', status.mode),
      if (status.plusActive) _metricChip('Plus', _planLabel(status.plan)),
      if (!status.plusActive && plusInRevenueCat)
        _metricChip('RevenueCat', 'Pending sync'),
      if (status.dakshana.totalCredits > 0)
        _metricChip('Dakshana', '${status.dakshana.totalCredits} left'),
    ];

    if (chips.length == 1) {
      chips.add(_metricChip('Access', 'Open'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A18).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border.withValues(alpha: 0.8)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, height: 1.1),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: _dim,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
              'RevenueCat products are still syncing. Cards stay visible, and purchase buttons unlock when offerings are returned.',
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

  Widget _planRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required Package? package,
    required bool disabled,
    required String disabledLabel,
  }) {
    final pending = package == null;
    final purchasing =
        package != null && _purchasingKey == _packageKey(package);
    final canTap = !pending && !disabled && _purchasingKey == null;
    final actionLabel = pending
        ? 'Sync pending'
        : disabled
            ? disabledLabel
            : 'Choose';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0A18).withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: _softGold, size: 18),
          ),
          const SizedBox(width: 12),
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
              onPressed: canTap ? () => _purchase(package) : null,
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
    if (error is PlatformException) {
      return error.message?.trim().isNotEmpty == true
          ? error.message!
          : error.code;
    }
    return error.toString();
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

    return offering.availablePackages.length == 1
        ? offering.availablePackages.first
        : null;
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
