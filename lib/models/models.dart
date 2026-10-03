enum MemberRole { owner, staff }

enum SyncStatus { pending, synced, failed }

class Profile {
  final String id;
  final String email;
  final String fullName;
  final String? phone;

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'phone': phone,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: j['email'] as String,
        fullName: j['fullName'] as String? ?? '',
        phone: j['phone'] as String?,
      );
}

class Business {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String currency;
  final String currencySymbol;
  final String ownerId;

  const Business({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.currency = 'NGN',
    this.currencySymbol = '₦',
    required this.ownerId,
  });

  Business copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? currency,
    String? currencySymbol,
  }) =>
      Business(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        currency: currency ?? this.currency,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        ownerId: ownerId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'currency': currency,
        'currencySymbol': currencySymbol,
        'ownerId': ownerId,
      };

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        currency: j['currency'] as String? ?? 'NGN',
        currencySymbol: j['currencySymbol'] as String? ?? '₦',
        ownerId: j['ownerId'] as String,
      );
}

class BusinessMember {
  final String id;
  final String businessId;
  final String userId;
  final MemberRole role;
  final String displayName;
  final String email;
  final bool isActive;

  const BusinessMember({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.role,
    required this.displayName,
    required this.email,
    this.isActive = true,
  });

  BusinessMember copyWith({bool? isActive, String? displayName}) =>
      BusinessMember(
        id: id,
        businessId: businessId,
        userId: userId,
        role: role,
        displayName: displayName ?? this.displayName,
        email: email,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'userId': userId,
        'role': role.name,
        'displayName': displayName,
        'email': email,
        'isActive': isActive,
      };

  factory BusinessMember.fromJson(Map<String, dynamic> j) => BusinessMember(
        id: j['id'] as String,
        businessId: j['businessId'] as String,
        userId: j['userId'] as String,
        role: MemberRole.values.firstWhere(
          (e) => e.name == j['role'],
          orElse: () => MemberRole.staff,
        ),
        displayName: j['displayName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        isActive: j['isActive'] as bool? ?? true,
      );
}

class Product {
  final String id;
  final String businessId;
  final String name;
  final String? sku;
  final double unitPrice;
  final double? costPrice;
  final String unit;
  final bool isActive;

  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.sku,
    required this.unitPrice,
    this.costPrice,
    this.unit = 'pcs',
    this.isActive = true,
  });

  Product copyWith({
    String? name,
    String? sku,
    double? unitPrice,
    double? costPrice,
    String? unit,
    bool? isActive,
  }) =>
      Product(
        id: id,
        businessId: businessId,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        unitPrice: unitPrice ?? this.unitPrice,
        costPrice: costPrice ?? this.costPrice,
        unit: unit ?? this.unit,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'name': name,
        'sku': sku,
        'unitPrice': unitPrice,
        'costPrice': costPrice,
        'unit': unit,
        'isActive': isActive,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        businessId: j['businessId'] as String,
        name: j['name'] as String,
        sku: j['sku'] as String?,
        unitPrice: (j['unitPrice'] as num).toDouble(),
        costPrice: (j['costPrice'] as num?)?.toDouble(),
        unit: j['unit'] as String? ?? 'pcs',
        isActive: j['isActive'] as bool? ?? true,
      );
}

class SaleItem {
  final String id;
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const SaleItem({
    required this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
        id: j['id'] as String,
        productId: j['productId'] as String?,
        productName: j['productName'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        lineTotal: (j['lineTotal'] as num).toDouble(),
      );
}

class Sale {
  final String id;
  final String businessId;
  final String recordedBy;
  final String recordedByName;
  final double total;
  final String? note;
  final DateTime soldAt;
  final List<SaleItem> items;
  final SyncStatus syncStatus;

  const Sale({
    required this.id,
    required this.businessId,
    required this.recordedBy,
    required this.recordedByName,
    required this.total,
    this.note,
    required this.soldAt,
    required this.items,
    this.syncStatus = SyncStatus.pending,
  });

  Sale copyWith({SyncStatus? syncStatus}) => Sale(
        id: id,
        businessId: businessId,
        recordedBy: recordedBy,
        recordedByName: recordedByName,
        total: total,
        note: note,
        soldAt: soldAt,
        items: items,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'recordedBy': recordedBy,
        'recordedByName': recordedByName,
        'total': total,
        'note': note,
        'soldAt': soldAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'syncStatus': syncStatus.name,
      };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        businessId: j['businessId'] as String,
        recordedBy: j['recordedBy'] as String,
        recordedByName: j['recordedByName'] as String? ?? '',
        total: (j['total'] as num).toDouble(),
        note: j['note'] as String?,
        soldAt: DateTime.parse(j['soldAt'] as String),
        items: (j['items'] as List)
            .map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        syncStatus: SyncStatus.values.firstWhere(
          (e) => e.name == j['syncStatus'],
          orElse: () => SyncStatus.synced,
        ),
      );
}

class Expense {
  final String id;
  final String businessId;
  final String recordedBy;
  final String recordedByName;
  final String description;
  final double amount;
  final String? categoryId;
  final String? categoryName;
  final String? note;
  final DateTime spentAt;
  final SyncStatus syncStatus;

  const Expense({
    required this.id,
    required this.businessId,
    required this.recordedBy,
    required this.recordedByName,
    required this.description,
    required this.amount,
    this.categoryId,
    this.categoryName,
    this.note,
    required this.spentAt,
    this.syncStatus = SyncStatus.pending,
  });

  Expense copyWith({SyncStatus? syncStatus}) => Expense(
        id: id,
        businessId: businessId,
        recordedBy: recordedBy,
        recordedByName: recordedByName,
        description: description,
        amount: amount,
        categoryId: categoryId,
        categoryName: categoryName,
        note: note,
        spentAt: spentAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'recordedBy': recordedBy,
        'recordedByName': recordedByName,
        'description': description,
        'amount': amount,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'note': note,
        'spentAt': spentAt.toIso8601String(),
        'syncStatus': syncStatus.name,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        businessId: j['businessId'] as String,
        recordedBy: j['recordedBy'] as String,
        recordedByName: j['recordedByName'] as String? ?? '',
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'] as String?,
        categoryName: j['categoryName'] as String?,
        note: j['note'] as String?,
        spentAt: DateTime.parse(j['spentAt'] as String),
        syncStatus: SyncStatus.values.firstWhere(
          (e) => e.name == j['syncStatus'],
          orElse: () => SyncStatus.synced,
        ),
      );
}

class ExpenseCategory {
  final String id;
  final String name;
  const ExpenseCategory({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory ExpenseCategory.fromJson(Map<String, dynamic> j) =>
      ExpenseCategory(id: j['id'] as String, name: j['name'] as String);
}

class SyncQueueItem {
  final String id;
  final String entity; // sale | expense | product
  final String entityId;
  final SyncStatus status;
  final DateTime createdAt;
  final String? error;
  final Map<String, dynamic>? payload;

  const SyncQueueItem({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.status,
    required this.createdAt,
    this.error,
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity': entity,
        'entityId': entityId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'error': error,
        'payload': payload,
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> j) => SyncQueueItem(
        id: j['id'] as String,
        entity: j['entity'] as String,
        entityId: j['entityId'] as String,
        status: SyncStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => SyncStatus.pending,
        ),
        createdAt: DateTime.parse(j['createdAt'] as String),
        error: j['error'] as String?,
        payload: j['payload'] == null
            ? null
            : Map<String, dynamic>.from(j['payload'] as Map),
      );
}
