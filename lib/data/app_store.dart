import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/supabase_config.dart';
import '../models/models.dart';

const _uuid = Uuid();

/// Hybrid offline-first store. Works fully without Supabase.
/// When [SupabaseConfig.isConfigured], sync_queue marks items for push
/// (simple outbox; live push left for parent wiring).
class AppStore extends ChangeNotifier {
  static const _storageKey = 'bizbook_v1_state';

  Profile? currentUser;
  Business? business;
  BusinessMember? membership;
  List<BusinessMember> members = [];
  List<Product> products = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];
  List<ExpenseCategory> categories = [];
  List<SyncQueueItem> syncQueue = [];
  /// Demo auth accounts: email -> {password, profile, role hint}
  final Map<String, _DemoAccount> _accounts = {};
  bool loaded = false;
  String? lastError;

  bool get isLoggedIn => currentUser != null;
  bool get isOwner => membership?.role == MemberRole.owner;
  bool get isStaff => membership?.role == MemberRole.staff;
  String get symbol => business?.currencySymbol ?? '₦';
  bool get supabaseReady => SupabaseConfig.isConfigured;

  int get pendingSyncCount =>
      syncQueue.where((e) => e.status == SyncStatus.pending).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      _seedDemoWorld();
      await _persist();
    } else {
      _hydrate(jsonDecode(raw) as Map<String, dynamic>);
      if (_accounts.isEmpty) {
        _seedDemoWorld(keepData: true);
        await _persist();
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'currentUserId': currentUser?.id,
        'accounts': _accounts.map((k, v) => MapEntry(k, v.toJson())),
        'business': business?.toJson(),
        'membershipId': membership?.id,
        'members': members.map((e) => e.toJson()).toList(),
        'products': products.map((e) => e.toJson()).toList(),
        'sales': sales.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'syncQueue': syncQueue.map((e) => e.toJson()).toList(),
      }),
    );
  }

  void _hydrate(Map<String, dynamic> j) {
    _accounts.clear();
    final acc = j['accounts'] as Map<String, dynamic>? ?? {};
    acc.forEach((k, v) {
      _accounts[k] = _DemoAccount.fromJson(Map<String, dynamic>.from(v as Map));
    });
    if (j['business'] != null) {
      business = Business.fromJson(Map<String, dynamic>.from(j['business'] as Map));
    }
    members = (j['members'] as List? ?? [])
        .map((e) => BusinessMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    products = (j['products'] as List? ?? [])
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    sales = (j['sales'] as List? ?? [])
        .map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    expenses = (j['expenses'] as List? ?? [])
        .map((e) => Expense.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    categories = (j['categories'] as List? ?? [])
        .map((e) =>
            ExpenseCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    syncQueue = (j['syncQueue'] as List? ?? [])
        .map((e) =>
            SyncQueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final uid = j['currentUserId'] as String?;
    if (uid != null) {
      for (final a in _accounts.values) {
        if (a.profile.id == uid) {
          currentUser = a.profile;
          break;
        }
      }
    }
    final mid = j['membershipId'] as String?;
    if (mid != null) {
      membership = members.cast<BusinessMember?>().firstWhere(
            (m) => m?.id == mid,
            orElse: () => null,
          );
    }
  }

  void _seedDemoWorld({bool keepData = false}) {
    const ownerEmail = 'owner@bizbook.demo';
    const staffEmail = 'staff@bizbook.demo';
    const pass = 'demo1234';

    final owner = Profile(
      id: 'user-owner-demo',
      email: ownerEmail,
      fullName: 'Haruna Saidu',
      phone: '+2348012345678',
    );
    final staff = Profile(
      id: 'user-staff-demo',
      email: staffEmail,
      fullName: 'Aisha Bello',
      phone: '+2348098765432',
    );
    _accounts[ownerEmail] = _DemoAccount(password: pass, profile: owner);
    _accounts[staffEmail] = _DemoAccount(password: pass, profile: staff);

    categories = const [
      ExpenseCategory(id: 'cat-rent', name: 'Rent'),
      ExpenseCategory(id: 'cat-util', name: 'Utilities'),
      ExpenseCategory(id: 'cat-trans', name: 'Transport'),
      ExpenseCategory(id: 'cat-supp', name: 'Supplies'),
      ExpenseCategory(id: 'cat-sal', name: 'Salaries'),
      ExpenseCategory(id: 'cat-mkt', name: 'Marketing'),
      ExpenseCategory(id: 'cat-other', name: 'Other'),
    ];

    if (keepData && business != null) return;

    business = Business(
      id: 'biz-haruna-stores',
      name: 'Haruna Stores',
      phone: '+2348012345678',
      email: 'hello@harunastores.demo',
      address: '12 Market Road, Kano',
      currency: 'NGN',
      currencySymbol: '₦',
      ownerId: owner.id,
    );

    members = [
      BusinessMember(
        id: 'mem-owner',
        businessId: business!.id,
        userId: owner.id,
        role: MemberRole.owner,
        displayName: owner.fullName,
        email: owner.email,
      ),
      BusinessMember(
        id: 'mem-staff',
        businessId: business!.id,
        userId: staff.id,
        role: MemberRole.staff,
        displayName: staff.fullName,
        email: staff.email,
      ),
    ];

    products = [
      Product(
        id: 'prod-rice',
        businessId: business!.id,
        name: 'Rice 50kg',
        sku: 'RIC-50',
        unitPrice: 65000,
        costPrice: 58000,
        unit: 'bag',
      ),
      Product(
        id: 'prod-oil',
        businessId: business!.id,
        name: 'Vegetable Oil 5L',
        sku: 'OIL-5',
        unitPrice: 8500,
        costPrice: 7200,
        unit: 'bottle',
      ),
      Product(
        id: 'prod-sugar',
        businessId: business!.id,
        name: 'Sugar 1kg',
        sku: 'SUG-1',
        unitPrice: 1800,
        costPrice: 1400,
        unit: 'pack',
      ),
      Product(
        id: 'prod-garri',
        businessId: business!.id,
        name: 'Garri 2kg',
        sku: 'GAR-2',
        unitPrice: 2500,
        costPrice: 2000,
        unit: 'pack',
      ),
      Product(
        id: 'prod-soap',
        businessId: business!.id,
        name: 'Detergent Soap',
        sku: 'SOAP-1',
        unitPrice: 1200,
        costPrice: 900,
        unit: 'pcs',
      ),
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    sales = [
      Sale(
        id: 'sale-1',
        businessId: business!.id,
        recordedBy: staff.id,
        recordedByName: staff.fullName,
        total: 76500,
        soldAt: today.add(const Duration(hours: 9, minutes: 15)),
        syncStatus: SyncStatus.synced,
        items: [
          SaleItem(
            id: 'si-1',
            productId: 'prod-rice',
            productName: 'Rice 50kg',
            quantity: 1,
            unitPrice: 65000,
            lineTotal: 65000,
          ),
          SaleItem(
            id: 'si-2',
            productId: 'prod-oil',
            productName: 'Vegetable Oil 5L',
            quantity: 1,
            unitPrice: 8500,
            lineTotal: 8500,
          ),
          SaleItem(
            id: 'si-3',
            productId: 'prod-soap',
            productName: 'Detergent Soap',
            quantity: 2,
            unitPrice: 1200,
            lineTotal: 2400,
          ),
        ],
      ),
      Sale(
        id: 'sale-2',
        businessId: business!.id,
        recordedBy: owner.id,
        recordedByName: owner.fullName,
        total: 5400,
        soldAt: today.add(const Duration(hours: 11, minutes: 40)),
        syncStatus: SyncStatus.synced,
        items: [
          SaleItem(
            id: 'si-4',
            productId: 'prod-sugar',
            productName: 'Sugar 1kg',
            quantity: 3,
            unitPrice: 1800,
            lineTotal: 5400,
          ),
        ],
      ),
      Sale(
        id: 'sale-3',
        businessId: business!.id,
        recordedBy: staff.id,
        recordedByName: staff.fullName,
        total: 5000,
        note: 'Walk-in cash',
        soldAt: today.subtract(const Duration(days: 1, hours: -14)),
        syncStatus: SyncStatus.synced,
        items: [
          SaleItem(
            id: 'si-5',
            productId: 'prod-garri',
            productName: 'Garri 2kg',
            quantity: 2,
            unitPrice: 2500,
            lineTotal: 5000,
          ),
        ],
      ),
    ];

    expenses = [
      Expense(
        id: 'exp-1',
        businessId: business!.id,
        recordedBy: owner.id,
        recordedByName: owner.fullName,
        description: 'Shop rent – October',
        amount: 80000,
        categoryId: 'cat-rent',
        categoryName: 'Rent',
        spentAt: today.subtract(const Duration(days: 2)),
        syncStatus: SyncStatus.synced,
      ),
      Expense(
        id: 'exp-2',
        businessId: business!.id,
        recordedBy: staff.id,
        recordedByName: staff.fullName,
        description: 'NEPA / prepaid token',
        amount: 15000,
        categoryId: 'cat-util',
        categoryName: 'Utilities',
        spentAt: today.add(const Duration(hours: 8)),
        syncStatus: SyncStatus.synced,
      ),
      Expense(
        id: 'exp-3',
        businessId: business!.id,
        recordedBy: staff.id,
        recordedByName: staff.fullName,
        description: 'Okada delivery to customer',
        amount: 2500,
        categoryId: 'cat-trans',
        categoryName: 'Transport',
        spentAt: today.add(const Duration(hours: 10, minutes: 20)),
        syncStatus: SyncStatus.synced,
      ),
    ];

    syncQueue = [
      SyncQueueItem(
        id: 'sq-demo',
        entity: 'sale',
        entityId: 'sale-1',
        status: SyncStatus.synced,
        createdAt: today,
      ),
    ];
  }

  // ── Auth ──────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    lastError = null;
    final key = email.trim().toLowerCase();
    final acc = _accounts[key];
    if (acc == null || acc.password != password) {
      lastError = 'Invalid email or password';
      notifyListeners();
      return false;
    }
    currentUser = acc.profile;
    membership = members.cast<BusinessMember?>().firstWhere(
          (m) => m?.userId == currentUser!.id && m!.isActive,
          orElse: () => null,
        );
    await _persist();
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    lastError = null;
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      lastError = 'Account already exists — try demo login';
      notifyListeners();
      return false;
    }
    final profile = Profile(
      id: _uuid.v4(),
      email: key,
      fullName: fullName.trim(),
      phone: phone,
    );
    _accounts[key] = _DemoAccount(password: password, profile: profile);
    currentUser = profile;
    membership = null;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    currentUser = null;
    membership = null;
    await _persist();
    notifyListeners();
  }

  Future<void> createBusiness({
    required String name,
    String? phone,
    String? email,
    String? address,
    String currency = 'NGN',
    String currencySymbol = '₦',
  }) async {
    if (currentUser == null) return;
    business = Business(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone,
      email: email,
      address: address,
      currency: currency,
      currencySymbol: currencySymbol,
      ownerId: currentUser!.id,
    );
    final mem = BusinessMember(
      id: _uuid.v4(),
      businessId: business!.id,
      userId: currentUser!.id,
      role: MemberRole.owner,
      displayName: currentUser!.fullName,
      email: currentUser!.email,
    );
    members = [mem];
    membership = mem;
    // if fresh register without demo products, keep empty catalogs
    if (products.isEmpty) {
      products = [];
      sales = [];
      expenses = [];
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateBusiness(Business updated) async {
    business = updated;
    await _persist();
    notifyListeners();
  }

  // ── Products ──────────────────────────────────────────
  Future<void> upsertProduct(Product p) async {
    final i = products.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      products = [...products]..[i] = p;
    } else {
      products = [...products, p];
    }
    _enqueue('product', p.id);
    await _persist();
    notifyListeners();
  }

  Future<void> setProductActive(String id, bool active) async {
    final i = products.indexWhere((e) => e.id == id);
    if (i < 0) return;
    products = [...products]..[i] = products[i].copyWith(isActive: active);
    await _persist();
    notifyListeners();
  }

  // ── Sales ─────────────────────────────────────────────
  Future<Sale> recordSale({
    required List<SaleItem> items,
    String? note,
    DateTime? soldAt,
  }) async {
    final total = items.fold<double>(0, (a, b) => a + b.lineTotal);
    final sale = Sale(
      id: _uuid.v4(),
      businessId: business!.id,
      recordedBy: currentUser!.id,
      recordedByName: currentUser!.fullName,
      total: total,
      note: note,
      soldAt: soldAt ?? DateTime.now(),
      items: items,
      syncStatus: SyncStatus.pending,
    );
    sales = [sale, ...sales];
    _enqueue('sale', sale.id);
    await _persist();
    notifyListeners();
    return sale;
  }

  Sale? saleById(String id) {
    try {
      return sales.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Expenses ──────────────────────────────────────────
  Future<Expense> recordExpense({
    required String description,
    required double amount,
    String? categoryId,
    String? categoryName,
    String? note,
    DateTime? spentAt,
  }) async {
    final exp = Expense(
      id: _uuid.v4(),
      businessId: business!.id,
      recordedBy: currentUser!.id,
      recordedByName: currentUser!.fullName,
      description: description.trim(),
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      note: note,
      spentAt: spentAt ?? DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    expenses = [exp, ...expenses];
    _enqueue('expense', exp.id);
    await _persist();
    notifyListeners();
    return exp;
  }

  // ── Staff ─────────────────────────────────────────────
  Future<String?> inviteStaff({
    required String email,
    required String displayName,
    String password = 'demo1234',
  }) async {
    if (!isOwner) return 'Only owners can add staff';
    final key = email.trim().toLowerCase();
    Profile profile;
    if (_accounts.containsKey(key)) {
      profile = _accounts[key]!.profile;
    } else {
      profile = Profile(
        id: _uuid.v4(),
        email: key,
        fullName: displayName.trim(),
      );
      _accounts[key] = _DemoAccount(password: password, profile: profile);
    }
    if (members.any((m) => m.userId == profile.id && m.isActive)) {
      return 'Staff already in this business';
    }
    final mem = BusinessMember(
      id: _uuid.v4(),
      businessId: business!.id,
      userId: profile.id,
      role: MemberRole.staff,
      displayName: displayName.trim(),
      email: key,
    );
    members = [...members, mem];
    await _persist();
    notifyListeners();
    return null;
  }

  Future<void> setMemberActive(String memberId, bool active) async {
    final i = members.indexWhere((e) => e.id == memberId);
    if (i < 0) return;
    members = [...members]..[i] = members[i].copyWith(isActive: active);
    await _persist();
    notifyListeners();
  }

  // ── Sync ──────────────────────────────────────────────
  void _enqueue(String entity, String entityId) {
    syncQueue = [
      SyncQueueItem(
        id: _uuid.v4(),
        entity: entity,
        entityId: entityId,
        status: supabaseReady ? SyncStatus.pending : SyncStatus.synced,
        createdAt: DateTime.now(),
        error: supabaseReady ? null : 'Demo mode — local only',
      ),
      ...syncQueue,
    ];
    // In demo mode mark as synced immediately for UX
    if (!supabaseReady) {
      _markEntitySynced(entity, entityId, SyncStatus.synced);
    }
  }

  void _markEntitySynced(String entity, String entityId, SyncStatus s) {
    if (entity == 'sale') {
      final i = sales.indexWhere((e) => e.id == entityId);
      if (i >= 0) sales = [...sales]..[i] = sales[i].copyWith(syncStatus: s);
    } else if (entity == 'expense') {
      final i = expenses.indexWhere((e) => e.id == entityId);
      if (i >= 0) {
        expenses = [...expenses]..[i] = expenses[i].copyWith(syncStatus: s);
      }
    }
  }

  Future<void> runSync() async {
    if (!supabaseReady) {
      // Mark all pending as synced in demo
      syncQueue = syncQueue
          .map((e) => SyncQueueItem(
                id: e.id,
                entity: e.entity,
                entityId: e.entityId,
                status: SyncStatus.synced,
                createdAt: e.createdAt,
                error: 'Demo mode — nothing to push',
              ))
          .toList();
      await _persist();
      notifyListeners();
      return;
    }
    // Placeholder: parent can wire real Supabase writes here.
    for (final item in List.of(syncQueue)) {
      if (item.status != SyncStatus.pending) continue;
      _markEntitySynced(item.entity, item.entityId, SyncStatus.synced);
    }
    syncQueue = syncQueue
        .map((e) => e.status == SyncStatus.pending
            ? SyncQueueItem(
                id: e.id,
                entity: e.entity,
                entityId: e.entityId,
                status: SyncStatus.synced,
                createdAt: e.createdAt,
              )
            : e)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    currentUser = null;
    membership = null;
    business = null;
    members = [];
    products = [];
    sales = [];
    expenses = [];
    syncQueue = [];
    _accounts.clear();
    _seedDemoWorld();
    await _persist();
    notifyListeners();
  }

  // ── Aggregates ────────────────────────────────────────

  bool _inRange(DateTime d, DateTime? from, DateTime? to) {
    if (from != null && d.isBefore(from)) return false;
    if (to != null && d.isAfter(to)) return false;
    return true;
  }

  double salesTotal({DateTime? from, DateTime? to, String? userId}) {
    return sales
        .where((s) =>
            _inRange(s.soldAt, from, to) &&
            (userId == null || s.recordedBy == userId))
        .fold(0.0, (a, s) => a + s.total);
  }

  double expensesTotal({DateTime? from, DateTime? to, String? userId}) {
    return expenses
        .where((e) =>
            _inRange(e.spentAt, from, to) &&
            (userId == null || e.recordedBy == userId))
        .fold(0.0, (a, e) => a + e.amount);
  }

  double salesToday({String? userId}) {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    return salesTotal(from: start, to: n.add(const Duration(days: 1)), userId: userId);
  }

  double salesMonth({String? userId}) {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, 1);
    return salesTotal(from: start, to: n.add(const Duration(days: 1)), userId: userId);
  }

  double expensesToday({String? userId}) {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    return expensesTotal(
        from: start, to: n.add(const Duration(days: 1)), userId: userId);
  }

  double expensesMonth({String? userId}) {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, 1);
    return expensesTotal(
        from: start, to: n.add(const Duration(days: 1)), userId: userId);
  }

  List<Sale> recentSales({int limit = 8, String? userId}) {
    final list = sales
        .where((s) => userId == null || s.recordedBy == userId)
        .toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    return list.take(limit).toList();
  }

  List<Expense> recentExpenses({int limit = 8, String? userId}) {
    final list = expenses
        .where((e) => userId == null || e.recordedBy == userId)
        .toList()
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    return list.take(limit).toList();
  }

  List<Map<String, dynamic>> staffActivity({int limit = 12}) {
    final events = <Map<String, dynamic>>[];
    for (final s in sales) {
      events.add({
        'type': 'sale',
        'title': 'Sale · ${s.items.map((i) => i.productName).take(2).join(', ')}',
        'amount': s.total,
        'by': s.recordedByName,
        'at': s.soldAt,
        'id': s.id,
      });
    }
    for (final e in expenses) {
      events.add({
        'type': 'expense',
        'title': e.description,
        'amount': e.amount,
        'by': e.recordedByName,
        'at': e.spentAt,
        'id': e.id,
      });
    }
    events.sort((a, b) =>
        (b['at'] as DateTime).compareTo(a['at'] as DateTime));
    return events.take(limit).toList();
  }
}

class _DemoAccount {
  final String password;
  final Profile profile;
  _DemoAccount({required this.password, required this.profile});

  Map<String, dynamic> toJson() => {
        'password': password,
        'profile': profile.toJson(),
      };
  factory _DemoAccount.fromJson(Map<String, dynamic> j) => _DemoAccount(
        password: j['password'] as String,
        profile: Profile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
      );
}
