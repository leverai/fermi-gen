import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:fermi_frontend/services/subscription_service.dart';

/// Paywall screen for displaying subscription options.
///
/// This screen fetches offerings from RevenueCat and displays them
/// in a custom UI matching the app's design system.
class PaywallScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  const PaywallScreen({
    super.key,
    required this.subscriptionService,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offerings = await widget.subscriptionService.getOfferings();
      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load subscription options';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.subscriptionService.purchasePackage(package);
      if (success && mounted) {
        Navigator.of(context).pop(true); // Return success
      } else {
        setState(() {
          _errorMessage = 'Purchase failed';
          _isPurchasing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Purchase error: $e';
        _isPurchasing = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.subscriptionService.restorePurchases();
      if (success && mounted) {
        Navigator.of(context).pop(true); // Return success
      } else {
        setState(() {
          _errorMessage = 'No purchases found to restore';
          _isPurchasing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Restore error: $e';
        _isPurchasing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _offerings == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOfferings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _offerings?.current == null
                  ? const Center(
                      child: Text('No subscription options available'),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Display packages from the current offering
                        ...(_offerings!.current!.availablePackages.map(
                          (package) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                title: Text(package.storeProduct.title),
                                subtitle: Text(package.storeProduct.description),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      package.storeProduct.priceString,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    if (package.packageType == PackageType.lifetime)
                                      const Text(
                                        'One-time',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                onTap: _isPurchasing
                                    ? null
                                    : () => _purchasePackage(package),
                              ),
                            );
                          },
                        )),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isPurchasing ? null : _restorePurchases,
                          child: const Text('Restore Purchases'),
                        ),
                      ],
                    ),
    );
  }
}
