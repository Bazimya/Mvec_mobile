import '../../../../core/api_client.dart';

/// A saved delivery address, normalised from `GET /auth/addresses`.
///
/// The backend stores the parts separately (`street`, `city`, `state`,
/// `postalCode`), which is also what checkout sends back, so the mapping is
/// lossless rather than flattening them into one line.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    this.isDefault = false,
  });

  final String id;
  final String fullName;
  final String phone;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final bool isDefault;

  /// Single-line form for display.
  String get summary =>
      [street, city, state].where((part) => part.isNotEmpty).join(', ');

  /// The shape `POST /orders/checkout` expects.
  Map<String, String> toShippingAddress() => <String, String>{
    'street': street,
    'city': city,
    'state': state,
    'country': 'Rwanda',
    'postalCode': postalCode,
  };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    id: json['id']?.toString() ?? '',
    fullName:
        json['fullName']?.toString() ?? json['contactName']?.toString() ?? '',
    phone:
        json['phoneNumber']?.toString() ??
        json['phone']?.toString() ??
        json['telephone']?.toString() ??
        '',
    street:
        json['street']?.toString() ??
        json['streetAddress']?.toString() ??
        json['address']?.toString() ??
        '',
    city: json['city']?.toString() ?? json['district']?.toString() ?? '',
    state:
        json['state']?.toString() ??
        json['province']?.toString() ??
        json['region']?.toString() ??
        '',
    postalCode: json['postalCode']?.toString() ?? '',
    isDefault: json['isDefault'] == true || json['default'] == true,
  );
}

/// Reads and writes the shopper's saved addresses.
///
/// The web storefront keeps checkout addresses in the form state and never calls
/// this resource, but the mobile checkout offers saved addresses so it needs the
/// read. Writing through the API keeps the list consistent across devices rather
/// than seeding local placeholder addresses.
class ApiAddressService {
  ApiAddressService([ApiClient? api]) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<SavedAddress>> addresses() async {
    final json = await _api.get('/auth/addresses');
    final rows = listJson(json, const ['addresses']);
    return rows.map(SavedAddress.fromJson).toList();
  }

  /// Saves a new address and returns the refreshed list.
  Future<List<SavedAddress>> add({
    required String fullName,
    required String phone,
    required String street,
    required String city,
    required String state,
    String postalCode = '',
  }) async {
    final json = await _api.post(
      '/auth/addresses',
      body: <String, dynamic>{
        'fullName': fullName,
        'phoneNumber': phone,
        'street': street,
        'city': city,
        'state': state,
        'country': 'Rwanda',
        'postalCode': postalCode,
      },
    );
    // Some deployments answer with the created address only, so fall back to
    // re-reading rather than showing an empty list.
    final rows = listJson(json, const ['addresses']);
    if (rows.isNotEmpty) return rows.map(SavedAddress.fromJson).toList();
    return addresses();
  }

  Future<void> remove(String id) async {
    await _api.delete('/auth/addresses/$id');
  }
}