import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../features/marketplace/data/services/api_address_service.dart';
import '../features/marketplace/data/services/api_order_service.dart';
import '../models/address.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final double subtotal;
  final double shippingFee;
  final double serviceFee;
  final double tax;
  final double total;
  final ValueChanged<Order> onOrderPlaced;

  /// Overridable so widget tests can drive checkout without a network.
  final ApiOrderService? orderService;
  final ApiAddressService? addressService;

  const CheckoutPage({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.shippingFee,
    required this.serviceFee,
    required this.tax,
    required this.total,
    required this.onOrderPlaced,
    this.orderService,
    this.addressService,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  /// Saved addresses from `GET /auth/addresses`. Empty means the shopper has
  /// none saved - it never falls back to seeded addresses.
  final List<SavedAddress> _addresses = [];

  SavedAddress? _selectedAddress;
  String _selectedPaymentMethod = 'Mobile Money';

  final List<String> _paymentMethods = [
    'Mobile Money',
    'Credit / Debit Card',
  ];

  bool _isSubmitting = false;
  bool _isLoadingAddresses = true;
  String? _addressError;
  String? _checkoutError;

  late final ApiOrderService _orders = widget.orderService ?? ApiOrderService();
  late final ApiAddressService _addressService =
      widget.addressService ?? ApiAddressService();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _paymentInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  /// Loads the shopper's saved addresses and preselects their default, so the
  /// common case is a single tap to place the order.
  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
      _addressError = null;
    });
    try {
      final addresses = await _addressService.addresses();
      if (!mounted) return;
      setState(() {
        _addresses
          ..clear()
          ..addAll(addresses);
        _selectedAddress ??= addresses.isEmpty
            ? null
            : addresses.firstWhere(
                (address) => address.isDefault,
                orElse: () => addresses.first,
              );
        _isLoadingAddresses = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _addressError = e.message;
        _isLoadingAddresses = false;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _paymentInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== 1. Delivery Address ==========
            _buildSectionTitle('Delivery Address'),
            const SizedBox(height: 10),
            _buildAddressSection(),
            const SizedBox(height: 24),

            // ========== 2. Order Review ==========
            _buildSectionTitle('Order Review'),
            const SizedBox(height: 10),
            _buildOrderReview(),
            const SizedBox(height: 24),

            // ========== 3. Payment Method ==========
            _buildSectionTitle('Payment Method'),
            const SizedBox(height: 10),
            _buildPaymentMethods(),
            const SizedBox(height: 24),

            // ========== 4. Order Summary ==========
            _buildSectionTitle('Order Summary'),
            const SizedBox(height: 10),
            _buildOrderSummary(),
            const SizedBox(height: 30),

            // ========== Checkout Error ==========
            if (_checkoutError != null) ...[
              _buildAddressNotice(
                _checkoutError!,
                actionLabel: 'Try again',
                onAction: _submitOrder,
              ),
              const SizedBox(height: 16),
            ],

            // ========== Place Order Button ==========
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm & Place Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==================== SECTION TITLE ====================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ==================== ADDRESS SECTION ====================
  Widget _buildAddressSection() {
    return Column(
      children: [
        if (_isLoadingAddresses)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_addressError != null && _addresses.isEmpty)
          _buildAddressNotice(
            'Could not load your addresses: $_addressError',
            actionLabel: 'Retry',
            onAction: _loadAddresses,
          )
        else if (_addresses.isEmpty)
          _buildAddressNotice('No delivery address saved yet. Add one to continue.'),
        ..._addresses.map((address) {
          final isSelected = _selectedAddress?.id == address.id;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedAddress = address;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address.phone,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address.summary,
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Add New Address Button
        OutlinedButton.icon(
          onPressed: _showAddAddressDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add New Address'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// Inline notice used for the loading-failed and no-address states.
  Widget _buildAddressNotice(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddAddressDialog() async {
    final formKey = GlobalKey<FormState>();
    _fullNameController.clear();
    _phoneController.clear();
    _addressController.clear();
    _cityController.clear();
    _regionController.clear();

    // Captured here so the dialog's save button can hand the entered values
    // back without mutating state during build.
    late SavedAddress pendingAddress;
    final address = await showDialog<SavedAddress>(
      context: context,
      // The dialog returns the raw form values; they are persisted through
      // `POST /auth/addresses` below so the address is the shopper's, not a
      // device-local placeholder.
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add delivery address'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _addressField(_fullNameController, 'Full name'),
                _addressField(_phoneController, 'Phone number', keyboardType: TextInputType.phone),
                _addressField(_addressController, 'Street address'),
                _addressField(_cityController, 'City'),
                _addressField(_regionController, 'Region'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              FocusScope.of(dialogContext).unfocus();
              pendingAddress = SavedAddress(
                id: '',
                fullName: _fullNameController.text.trim(),
                phone: _phoneController.text.trim(),
                street: _addressController.text.trim(),
                city: _cityController.text.trim(),
                state: _regionController.text.trim(),
                postalCode: '',
                isDefault: _addresses.isEmpty,
              );
              Navigator.pop(dialogContext, pendingAddress);
            },
            child: const Text('Save address'),
          ),
        ],
      ),
    );

    if (address == null) return;
    await _saveAddress(address);
  }

  /// Persists a newly entered address, then refreshes from the backend so the
  /// list shows what was actually stored (including any server-assigned id).
  Future<void> _saveAddress(SavedAddress address) async {
    setState(() {
      _isSubmitting = true;
      _addressError = null;
    });
    try {
      final saved = await _addressService.add(
        fullName: address.fullName,
        phone: address.phone,
        street: address.street,
        city: address.city,
        state: address.state,
      );
      if (!mounted) return;
      setState(() {
        _addresses
          ..clear()
          ..addAll(saved);
        _selectedAddress = saved.isEmpty
            ? address
            : saved.firstWhere(
                (entry) => entry.street == address.street,
                orElse: () => saved.last,
              );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _addressError = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _addressField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter $label'
            : null,
      ),
    );
  }

  // ==================== ORDER REVIEW ====================
  Widget _buildOrderReview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: widget.cartItems.map((item) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.product.images.isNotEmpty
                      ? Image.network(
                          item.product.images.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${item.quantity}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== PAYMENT METHODS ====================
  Widget _buildPaymentMethods() {
    return Column(
      children: _paymentMethods.map((method) {
        final isSelected = _selectedPaymentMethod == method;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method;
              _paymentInputController.clear();
            });
          },
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        method,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) _buildPaymentInput(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentInput() {
    final isMobileMoney = _selectedPaymentMethod == 'Mobile Money';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _paymentInputController,
        keyboardType: isMobileMoney
            ? TextInputType.phone
            : TextInputType.number,
        decoration: InputDecoration(
          labelText: isMobileMoney ? 'Mobile money phone number' : 'Card number',
          hintText: isMobileMoney ? '+2507 -------' : '1234 5678 9012 3456',
          prefixIcon: Icon(
            isMobileMoney ? Icons.phone_outlined : Icons.credit_card_outlined,
          ),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // ==================== ORDER SUMMARY ====================
  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', widget.subtotal),
          const SizedBox(height: 8),
          _buildSummaryRow('Shipping Fee', widget.shippingFee),
          const SizedBox(height: 8),
          _buildSummaryRow('Service Fee', widget.serviceFee),
          const SizedBox(height: 8),
          _buildSummaryRow('Tax', widget.tax),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          _buildSummaryRow('Total', widget.total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 17 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: isTotal ? Theme.of(context).primaryColor : Colors.black,
          ),
        ),
      ],
    );
  }

  // ==================== SUBMIT ORDER ====================
  /// Creates the order on the backend from the server-side cart, then starts
  /// the payment the shopper chose.
  ///
  /// The order is only reported as placed once `POST /orders/checkout` returns
  /// one - nothing is invented locally, so a failure leaves the shopper on the
  /// form with the backend's message instead of a confirmation for an order that
  /// does not exist.
  Future<void> _submitOrder() async {
    final address = _selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    final paymentInput = _paymentInputController.text.trim();
    if (paymentInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedPaymentMethod == 'Mobile Money'
                ? 'Enter your mobile money phone number'
                : 'Enter your card number',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _checkoutError = null;
    });

    try {
      final order = await _orders.checkout(
        shippingAddress: address.toShippingAddress(),
        paymentMethod: _selectedPaymentMethod,
      );

      // Payment is initiated against the created order. Mobile money resolves
      // asynchronously after the shopper approves the USSD prompt, so the
      // dialog says "awaiting confirmation" rather than claiming success.
      var awaitingConfirmation = false;
      if (_selectedPaymentMethod == 'Mobile Money') {
        await _orders.initiateMobileMoney(
          orderId: order.id,
          phoneNumber: paymentInput,
        );
        awaitingConfirmation = true;
      } else {
        final redirect = await _orders.initiateKpayCard(order.id);
        if (redirect != null) {
          await _openCardPayment(redirect, order);
          return;
        }
        awaitingConfirmation = true;
      }

      if (!mounted) return;
      await _showPlacedDialog(order, awaitingConfirmation: awaitingConfirmation);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _checkoutError = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// K-Pay card payments finish on the provider's page, so the shopper is sent
  /// to that page in their browser rather than being shown a bare URL.
  ///
  /// The confirmation dialog is shown first: it explains what is about to
  /// happen and keeps the order summary on screen if the browser fails to open.
  Future<void> _openCardPayment(String redirectUrl, BuyerOrder order) async {
    // Captured before the dialog so it is not used across the async gaps.
    final messenger = ScaffoldMessenger.of(context);

    await _showPlacedDialog(order, awaitingConfirmation: true);

    final uri = Uri.tryParse(redirectUrl);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;

    // The browser could not be opened (no handler, or an unusable URL), so the
    // link is surfaced rather than silently dropped.
    messenger.showSnackBar(
      SnackBar(
        content: Text('Open this link to complete card payment: $redirectUrl'),
        duration: const Duration(seconds: 12),
      ),
    );
  }

  Future<void> _showPlacedDialog(
    BuyerOrder order, {
    required bool awaitingConfirmation,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              awaitingConfirmation ? Icons.schedule : Icons.check_circle,
              color: awaitingConfirmation ? Colors.orange : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(awaitingConfirmation ? 'Order placed' : 'Order placed'),
          ],
        ),
        content: Text(
          awaitingConfirmation
              ? 'Order ${order.orderNumber} was created. Approve the payment '
                  'prompt on your phone to complete it.'
              : 'Order ${order.orderNumber} was created.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close dialog
              widget.onOrderPlaced(_buildOrder(order));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Projects the backend's order onto the local `Order` the tracking page
  /// renders. Totals come from the backend rather than this form's estimate,
  /// since the server is the authority on what was charged.
  Order _buildOrder(BuyerOrder order) {
    return Order(
      id: order.id,
      orderNumber: order.orderNumber,
      orderDate: order.createdAt ?? DateTime.now(),
      status: switch (order.status) {
        BuyerOrderStatus.pending => OrderStatus.pending,
        BuyerOrderStatus.confirmed => OrderStatus.confirmed,
        BuyerOrderStatus.processing => OrderStatus.processing,
        BuyerOrderStatus.shipped => OrderStatus.shipped,
        BuyerOrderStatus.outForDelivery => OrderStatus.outForDelivery,
        BuyerOrderStatus.delivered => OrderStatus.delivered,
        BuyerOrderStatus.cancelled => OrderStatus.cancelled,
        BuyerOrderStatus.unknown => OrderStatus.pending,
      },
      items: List<CartItem>.from(widget.cartItems),
      deliveryAddress: Address(
        id: _selectedAddress?.id ?? '',
        fullName: _selectedAddress?.fullName ?? '',
        phone: _selectedAddress?.phone ?? '',
        addressLine: _selectedAddress?.street ?? '',
        city: _selectedAddress?.city ?? '',
        region: _selectedAddress?.state ?? '',
      ),
      paymentMethod: _selectedPaymentMethod,
      subtotal: widget.subtotal,
      shippingFee: widget.shippingFee,
      serviceFee: widget.serviceFee,
      tax: widget.tax,
      total: order.total == 0 ? widget.total : order.total,
    );
  }
}