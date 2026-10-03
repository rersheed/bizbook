import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../core/supabase_config.dart';
import '../models/models.dart';

const _uuid = Uuid();

/// Online store backed by Supabase Auth + Postgres.
/// A short local queue retries customers, sales, expenses, credits,
/// repayments, and products if the network drops.
class AppStore extends ChangeNotifier {
  static const _queueKey = 'bizbook_sync_queue_v2';

  Profile? currentUser;
  Business? business;
  BusinessMember? membership;
  List<BusinessMember> members = [];
  List<Product> products = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];
  List<ExpenseCategory> categories = [];
  List<Customer> customers = [];
  List<CustomerCredit> credits = [];
  List<CreditRepayment> repayments = [];
  List<SyncQueueItem> syncQueue = [];
  bool loaded = false;
  bool accessDisabled = false;
  String? lastError;
  String? staffNotice;
  /// True when sign-up succeeded but the user must confirm their email first.
  bool pendingEmailConfirm = false;

  bool get isLoggedIn => currentUser != null;
  bool get isOwner => membership?.role == MemberRole.owner;
  bool get isStaff => membership?.role == MemberRole.staff;
  String get symbol => business?.currencySymbol ?? '₦';
  bool get supabaseReady => _db != null;

  int get pendingSyncCount =>
      syncQueue.where((e) => e.status != SyncStatus.synced).length;

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bizbook_v1_state');
    final raw = prefs.getString(_queueKey);
    if (raw != null) {
      syncQueue = (jsonDecode(raw) as List)
          .map((e) =>
              SyncQueueItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final db = _db;
    if (db != null && db.auth.currentSession != null) {
      try {
        await refresh();
        await runSync();
      } catch (e) {
        lastError = _msg(e);
      }
    }
    _materializePending();
    loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    final db = _db;
    final user = db?.auth.currentUser;
    if (db == null || user == null) {
      _clearSessionData();
      return;
    }
    accessDisabled = false;
    lastError = null;

    final profileRaw =
        await db.from('profiles').select().eq('id', user.id).maybeSingle();
    final profile =
        profileRaw == null ? null : Map<String, dynamic>.from(profileRaw);
    var fullName = (profile?['full_name'] as String?)?.trim() ?? '';
    if (fullName.isEmpty) {
      fullName = (user.userMetadata?['full_name'] as String?)?.trim() ?? '';
      if (fullName.isNotEmpty) {
        await db.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': fullName,
          'phone': user.userMetadata?['phone'],
        });
      }
    }
    currentUser = Profile(
      id: user.id,
      email: (profile?['email'] as String?) ?? user.email ?? '',
      fullName: fullName.isEmpty ? (user.email ?? 'User') : fullName,
      phone: profile?['phone'] as String? ?? user.userMetadata?['phone'] as String?,
    );

    final memRaw = await db.from('business_members').select().eq('user_id', user.id);
    final memRows = _rows(memRaw);
    final active = memRows.where((m) => m['is_active'] == true).toList();
    if (memRows.isNotEmpty && active.isEmpty) {
      accessDisabled = true;
      business = null;
      membership = null;
      members = [];
      products = [];
      sales = [];
      expenses = [];
      customers = [];
      credits = [];
      repayments = [];
      await _loadCategories(null);
      lastError = 'Your access to this business is disabled. Ask the owner.';
      notifyListeners();
      return;
    }

    if (active.isEmpty) {
      business = null;
      membership = null;
      members = [];
      products = [];
      sales = [];
      expenses = [];
      customers = [];
      credits = [];
      repayments = [];
      await _loadCategories(null);
      notifyListeners();
      return;
    }

    final mine = Map<String, dynamic>.from(active.first);
    final bizId = mine['business_id'] as String;
    final bizRaw =
        await db.from('businesses').select().eq('id', bizId).maybeSingle();
    if (bizRaw == null) {
      business = null;
      membership = null;
      notifyListeners();
      return;
    }
    business = _business(_map(bizRaw));
    membership = _member(mine);

    final memberList = _rows(
      await db.from('business_members').select().eq('business_id', bizId),
    );
    members = memberList.map(_member).toList();

    final productList = _rows(
      await db
          .from('products')
          .select()
          .eq('business_id', bizId)
          .isFilter('deleted_at', null)
          .order('name'),
    );
    products = productList.map(_product).toList();

    final saleList = _rows(
      await db
          .from('sales')
          .select('*, sale_items(*)')
          .eq('business_id', bizId)
          .isFilter('deleted_at', null)
          .order('sale_date', ascending: false),
    );
    sales = saleList.map(_sale).toList();

    final expenseList = _rows(
      await db
          .from('expenses')
          .select()
          .eq('business_id', bizId)
          .isFilter('deleted_at', null)
          .order('expense_date', ascending: false),
    );
    expenses = expenseList.map(_expense).toList();

    final customerList = _rows(
      await db
          .from('customers')
          .select()
          .eq('business_id', bizId)
          .isFilter('deleted_at', null)
          .order('name'),
    );
    customers = customerList.map(_customer).toList();

    final creditList = _rows(
      await db
          .from('customer_credits')
          .select()
          .eq('business_id', bizId)
          .isFilter('deleted_at', null)
          .order('credit_date', ascending: false),
    );
    credits = creditList.map(_credit).toList();

    final repaymentList = _rows(
      await db
          .from('credit_repayments')
          .select()
          .eq('business_id', bizId)
          .isFilter('deleted_at', null)
          .order('repayment_date', ascending: false),
    );
    repayments = repaymentList.map(_repayment).toList();

    await _loadCategories(bizId);
    _materializePending();
    notifyListeners();
  }

  Future<void> _loadCategories(String? businessId) async {
    final db = _db;
    if (db == null) {
      categories = [];
      return;
    }
    final global = _rows(
      await db.from('expense_categories').select().isFilter('business_id', null),
    );
    final own = businessId == null
        ? <Map<String, dynamic>>[]
        : _rows(
            await db
                .from('expense_categories')
                .select()
                .eq('business_id', businessId),
          );
    final seen = <String>{};
    categories = [];
    for (final row in [...own, ...global]) {
      final id = row['id'].toString();
      if (!seen.add(id)) continue;
      categories.add(ExpenseCategory(id: id, name: row['name'] as String? ?? ''));
    }
  }

  Future<bool> login(String email, String password) async {
    lastError = null;
    accessDisabled = false;
    final db = _db;
    if (db == null) {
      lastError = 'Supabase is not configured';
      notifyListeners();
      return false;
    }
    try {
      await db.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await refresh();
      if (accessDisabled) {
        final msg = lastError;
        await logout(keepError: true);
        lastError = msg;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      lastError = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    lastError = null;
    pendingEmailConfirm = false;
    final db = _db;
    if (db == null) {
      lastError = 'Supabase is not configured';
      notifyListeners();
      return false;
    }
    try {
      final res = await db.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      if (res.session == null) {
        pendingEmailConfirm = true;
        lastError =
            'Check your email to confirm the account, then sign in.';
        notifyListeners();
        return false;
      }
      await refresh();
      return true;
    } catch (e) {
      lastError = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout({bool keepError = false}) async {
    final err = lastError;
    try {
      await _db?.auth.signOut();
    } catch (_) {}
    _clearSessionData();
    pendingEmailConfirm = false;
    if (keepError) lastError = err;
    notifyListeners();
  }

  void _clearSessionData() {
    currentUser = null;
    business = null;
    membership = null;
    members = [];
    products = [];
    sales = [];
    expenses = [];
    categories = [];
    customers = [];
    credits = [];
    repayments = [];
    accessDisabled = false;
  }

  Future<bool> createBusiness({
    required String name,
    String? phone,
    String? email,
    String? address,
    String currency = 'NGN',
    String currencySymbol = '₦',
  }) async {
    lastError = null;
    final db = _db;
    if (db == null || currentUser == null) {
      lastError = 'Sign in first';
      notifyListeners();
      return false;
    }
    String? createdId;
    try {
      final created = _map(
        await db.from('businesses').insert({
          'business_name': name.trim(),
          'owner_user_id': currentUser!.id,
          'phone': phone,
          'email': email,
          'address': address,
          'currency_code': currency,
          'currency_symbol': currencySymbol,
        }).select().single(),
      );
      createdId = created['id'] as String;
      await db.from('business_members').insert({
        'business_id': createdId,
        'user_id': currentUser!.id,
        'role': 'owner',
        'name': currentUser!.fullName,
        'email': currentUser!.email,
        'is_active': true,
      });
      await refresh();
      return business != null;
    } catch (e) {
      if (createdId != null) {
        try {
          await db.from('businesses').delete().eq('id', createdId);
        } catch (_) {}
      }
      lastError = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBusiness(Business updated) async {
    lastError = null;
    final db = _db;
    if (db == null) return false;
    try {
      await db.from('businesses').update({
        'business_name': updated.name,
        'phone': updated.phone,
        'email': updated.email,
        'address': updated.address,
        'currency_code': updated.currency,
        'currency_symbol': updated.currencySymbol,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', updated.id);
      business = updated;
      notifyListeners();
      return true;
    } catch (e) {
      lastError = _msg(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> upsertProduct(Product p) async {
    lastError = null;
    final i = products.indexWhere((e) => e.id == p.id);
    products = i >= 0 ? ([...products]..[i] = p) : [...products, p];
    notifyListeners();
    final payload = {
      'id': p.id,
      'business_id': p.businessId,
      'name': p.name,
      'selling_price': p.unitPrice,
      'description': null,
      'sku': p.sku,
      'unit': p.unit,
      'cost_price': p.costPrice,
      'is_active': p.isActive,
    };
    await _attempt(
      entity: 'product',
      entityId: p.id,
      payload: payload,
      op: () async {
        await _db!.from('products').upsert(payload);
      },
    );
  }

  Future<void> setProductActive(String id, bool active) async {
    final i = products.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final next = products[i].copyWith(isActive: active);
    products = [...products]..[i] = next;
    notifyListeners();
    await upsertProduct(next);
  }

  Future<Sale> recordSale({
    required List<SaleItem> items,
    String? note,
    DateTime? soldAt,
    String? customerId,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    int? paidKobo,
    DateTime? dueDate,
  }) async {
    lastError = null;
    if (business == null || currentUser == null) {
      lastError = 'Sign in first';
      notifyListeners();
      return _rejectedSale(items);
    }
    final normalized = <SaleItem>[];
    var totalKobo = 0;
    for (final item in items) {
      final kobo = lineKobo(item.quantity, item.unitPrice);
      totalKobo += kobo;
      normalized.add(SaleItem(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotal: koboToMoney(kobo),
      ));
    }
    if (totalKobo <= 0) {
      lastError = 'Enter an amount greater than 0';
      notifyListeners();
      return _rejectedSale(items);
    }

    var paid = totalKobo;
    var onCredit = 0;
    if (paymentStatus == PaymentStatus.credit) {
      paid = 0;
      onCredit = totalKobo;
    } else if (paymentStatus == PaymentStatus.partial) {
      paid = paidKobo ?? 0;
      onCredit = totalKobo - paid;
    }
    if (paymentStatus != PaymentStatus.paid &&
        (customerId == null || customerId.isEmpty)) {
      lastError = 'Choose a customer for partial and credit sales';
      notifyListeners();
      return _rejectedSale(items);
    }
    if (paymentStatus == PaymentStatus.partial && (paid <= 0 || onCredit <= 0)) {
      lastError = 'Partial payment must be more than 0 and less than the total';
      notifyListeners();
      return _rejectedSale(items);
    }

    final when = soldAt ?? DateTime.now();
    final sale = Sale(
      id: _uuid.v4(),
      businessId: business!.id,
      recordedBy: currentUser!.id,
      recordedByName: currentUser!.fullName,
      total: koboToMoney(totalKobo),
      customerId: customerId,
      paymentStatus: paymentStatus,
      amountPaid: koboToMoney(paid),
      amountOnCredit: koboToMoney(onCredit),
      note: note,
      soldAt: when,
      items: normalized,
      syncStatus: SyncStatus.pending,
    );
    CustomerCredit? credit;
    if (onCredit > 0) {
      final names = normalized.map((i) => i.productName).where((n) => n.isNotEmpty).join(', ');
      final description = names.isEmpty
          ? 'Credit sale'
          : (names.length > 140 ? '${names.substring(0, 137)}...' : names);
      credit = CustomerCredit(
        id: _uuid.v4(),
        businessId: business!.id,
        customerId: customerId!,
        saleId: sale.id,
        recordedBy: currentUser!.id,
        recordedByName: currentUser!.fullName,
        description: description,
        originalAmount: koboToMoney(onCredit),
        outstandingAmount: koboToMoney(onCredit),
        creditDate: when,
        dueDate: dueDate,
        status: CreditStatus.unpaid,
        note: note,
        syncStatus: SyncStatus.pending,
      );
    }

    sales = [sale, ...sales];
    if (credit != null) credits = [credit, ...credits];
    notifyListeners();

    final customerPending = customerId != null &&
        customerById(customerId)?.syncStatus == SyncStatus.pending;
    final salePayload = _salePayload(sale);
    final SyncStatus saleStatus;
    if (customerPending) {
      saleStatus = SyncStatus.pending;
      _queueNew('sale', sale.id, saleStatus, null, salePayload);
      await _persistQueue();
    } else {
      saleStatus = await _attempt(
        entity: 'sale',
        entityId: sale.id,
        payload: salePayload,
        op: () => _pushSale(salePayload),
      );
    }
    final linked = credit;
    if (linked != null) {
      final creditPayload = _creditPayload(linked, asNew: true);
      final SyncStatus creditStatus;
      if (saleStatus == SyncStatus.synced) {
        creditStatus = await _attempt(
          entity: 'credit',
          entityId: linked.id,
          payload: creditPayload,
          op: () => _pushCredit(creditPayload),
        );
      } else {
        creditStatus = saleStatus;
        _queueNew(
          'credit',
          linked.id,
          creditStatus,
          saleStatus == SyncStatus.failed ? lastError : null,
          creditPayload,
        );
        await _persistQueue();
      }
      final ci = credits.indexWhere((c) => c.id == linked.id);
      if (ci >= 0) {
        credits = [...credits]..[ci] = linked.copyWith(syncStatus: creditStatus);
      }
      if (saleStatus == SyncStatus.synced && creditStatus == SyncStatus.failed) {
        lastError ??= 'Sale saved, but the linked credit did not sync';
      }
    }
    final saved = sale.copyWith(syncStatus: saleStatus);
    final idx = sales.indexWhere((s) => s.id == sale.id);
    if (idx >= 0) sales = [...sales]..[idx] = saved;
    _recomputeCredits();
    notifyListeners();
    return saved;
  }

  Sale _rejectedSale(List<SaleItem> items) => Sale(
        id: _uuid.v4(),
        businessId: business?.id ?? '',
        recordedBy: currentUser?.id ?? '',
        recordedByName: currentUser?.fullName ?? '',
        total: 0,
        soldAt: DateTime.now(),
        items: items,
        syncStatus: SyncStatus.failed,
      );

  Sale? saleById(String id) {
    try {
      return sales.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Expense> recordExpense({
    required String description,
    required double amount,
    String? categoryId,
    String? categoryName,
    String? note,
    DateTime? spentAt,
  }) async {
    lastError = null;
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
    notifyListeners();
    final payload = {
      'id': exp.id,
      'business_id': exp.businessId,
      'recorded_by': exp.recordedBy,
      'recorded_by_name': exp.recordedByName,
      'description': exp.description,
      'amount': exp.amount,
      'category_id': exp.categoryId,
      'category_name': exp.categoryName,
      'note': exp.note,
      'expense_date': exp.spentAt.toUtc().toIso8601String(),
    };
    final status = await _attempt(
      entity: 'expense',
      entityId: exp.id,
      payload: payload,
      op: () => _pushExpense(payload),
    );
    final saved = exp.copyWith(syncStatus: status);
    final idx = expenses.indexWhere((e) => e.id == exp.id);
    if (idx >= 0) expenses = [...expenses]..[idx] = saved;
    notifyListeners();
    return saved;
  }

  /// Creates a staff Auth user (without replacing the owner session) and
  /// adds them to this business. If the email already exists, links that user.
  Future<String?> inviteStaff({
    required String email,
    required String displayName,
    String password = '',
  }) async {
    lastError = null;
    staffNotice = null;
    if (!isOwner) return 'Only owners can add staff';
    final db = _db;
    if (db == null || business == null) return 'Not signed in';
    final key = email.trim().toLowerCase();
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (members.any((m) => m.email.toLowerCase() == key && m.isActive)) {
      return 'Staff already in this business';
    }
    try {
      final created = await _signUpStaff(key, password, displayName.trim());
      if (created.existing) {
        await db.rpc('attach_staff', params: {
          'p_business_id': business!.id,
          'p_email': key,
          'p_name': displayName.trim(),
        });
        staffNotice = 'Existing account linked. They can sign in with their password.';
      } else if (created.userId != null) {
        await db.from('business_members').insert({
          'business_id': business!.id,
          'user_id': created.userId,
          'role': 'staff',
          'name': displayName.trim(),
          'email': key,
          'is_active': true,
        });
        staffNotice = created.confirmed
            ? 'Staff added. They can sign in with that email and password.'
            : 'Staff added. They must confirm their email before signing in.';
      } else {
        return 'Could not create that staff login';
      }
      await refresh();
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<void> setMemberActive(String memberId, bool active) async {
    lastError = null;
    final db = _db;
    final i = members.indexWhere((e) => e.id == memberId);
    if (i < 0 || db == null) return;
    final prev = members[i];
    members = [...members]..[i] = prev.copyWith(isActive: active);
    notifyListeners();
    try {
      await db.from('business_members').update({
        'is_active': active,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', memberId);
    } catch (e) {
      members = [...members]..[i] = prev;
      lastError = _msg(e);
      notifyListeners();
    }
  }

  Future<void> runSync() async {
    final db = _db;
    if (db == null || db.auth.currentSession == null) {
      notifyListeners();
      return;
    }
    final pending = [
      for (final item in syncQueue)
        if (item.status != SyncStatus.synced && item.payload != null) item,
    ]..sort((a, b) {
        final rank = _entityRank(a.entity).compareTo(_entityRank(b.entity));
        if (rank != 0) return rank;
        return a.createdAt.compareTo(b.createdAt);
      });
    for (final item in pending) {
      try {
        if (item.entity == 'customer') {
          await _pushCustomer(item.payload!);
        } else if (item.entity == 'sale') {
          await _pushSale(item.payload!);
        } else if (item.entity == 'expense') {
          await _pushExpense(item.payload!);
        } else if (item.entity == 'product') {
          await db.from('products').upsert(item.payload!);
        } else if (item.entity == 'credit') {
          await _pushCredit(item.payload!);
        } else if (item.entity == 'repayment') {
          await _pushRepayment(item.payload!);
        } else {
          continue;
        }
        _mark(item.entity, item.entityId, SyncStatus.synced);
        _queueStatus(item, SyncStatus.synced, null);
      } catch (e) {
        final status = _isOffline(e) ? SyncStatus.pending : SyncStatus.failed;
        _mark(item.entity, item.entityId, status);
        _queueStatus(item, status, _msg(e));
        if (!_isOffline(e)) lastError = _msg(e);
      }
    }
    await _persistQueue();
    _recomputeCredits();
    notifyListeners();
  }

  Future<SyncStatus> _attempt({
    required String entity,
    required String entityId,
    required Map<String, dynamic> payload,
    required Future<void> Function() op,
  }) async {
    final db = _db;
    if (db == null || db.auth.currentSession == null) {
      lastError = 'Sign in to save to Supabase';
      _queueNew(entity, entityId, SyncStatus.failed, lastError, payload);
      await _persistQueue();
      return SyncStatus.failed;
    }
    try {
      await op();
      _queueNew(entity, entityId, SyncStatus.synced, null, null);
      await _persistQueue();
      return SyncStatus.synced;
    } catch (e) {
      final offline = _isOffline(e);
      final status = offline ? SyncStatus.pending : SyncStatus.failed;
      if (!offline) lastError = _msg(e);
      _queueNew(entity, entityId, status, offline ? null : _msg(e), payload);
      await _persistQueue();
      return status;
    }
  }

  Future<void> _pushSale(Map<String, dynamic> payload) async {
    final db = _db!;
    final items = (payload['items'] as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return {
        'id': m['id'],
        'sale_id': payload['id'],
        'business_id': payload['business_id'],
        'product_id': m['product_id'],
        'description': m['description'],
        'quantity': m['quantity'],
        'unit_price': m['unit_price'],
        'total_amount': m['total_amount'],
      };
    }).toList();
    final saleRow = Map<String, dynamic>.from(payload)..remove('items');
    final existing =
        await db.from('sales').select('id').eq('id', payload['id']).maybeSingle();
    if (existing == null) {
      await db.from('sales').insert(saleRow);
    }
    if (items.isEmpty) return;
    final have = _rows(
      await db.from('sale_items').select('id').eq('sale_id', payload['id']),
    ).map((e) => e['id'].toString()).toSet();
    final missing = items.where((e) => !have.contains(e['id'].toString())).toList();
    if (missing.isNotEmpty) {
      await db.from('sale_items').insert(missing);
    }
  }

  Future<void> _pushExpense(Map<String, dynamic> payload) async {
    final db = _db!;
    final existing = await db
        .from('expenses')
        .select('id')
        .eq('id', payload['id'])
        .maybeSingle();
    if (existing == null) {
      await db.from('expenses').insert(payload);
    }
  }

  Future<_StaffSignup> _signUpStaff(
    String email,
    String password,
    String displayName,
  ) async {
    final resp = await http.post(
      Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'data': {'full_name': displayName},
      }),
    );
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Unexpected signup response');
    }
    final body = Map<String, dynamic>.from(decoded);
    final message = (body['msg'] ?? body['error_description'] ?? body['message'] ?? body['error'])
        ?.toString();
    if (resp.statusCode >= 400) {
      if ((message ?? '').toLowerCase().contains('already')) {
        return const _StaffSignup.existing();
      }
      throw Exception(message ?? 'Could not create staff login');
    }
    final userMap = body['user'] is Map
        ? Map<String, dynamic>.from(body['user'] as Map)
        : body;
    final identities = userMap['identities'];
    final already = identities is List && identities.isEmpty;
    if (already) return const _StaffSignup.existing();
    final confirmed = userMap['email_confirmed_at'] != null ||
        body['access_token'] != null;
    return _StaffSignup(userId: userMap['id']?.toString(), confirmed: confirmed);
  }

  Map<String, dynamic> _salePayload(Sale sale) => {
        'id': sale.id,
        'business_id': sale.businessId,
        'customer_id': sale.customerId,
        'recorded_by': sale.recordedBy,
        'recorded_by_name': sale.recordedByName,
        'sale_date': sale.soldAt.toUtc().toIso8601String(),
        'total_amount': koboToNumeric(moneyToKobo(sale.total)),
        'payment_status': sale.paymentStatus.name,
        'amount_paid': koboToNumeric(moneyToKobo(sale.amountPaid)),
        'amount_on_credit': koboToNumeric(moneyToKobo(sale.amountOnCredit)),
        'note': sale.note,
        'items': sale.items
            .map((i) => {
                  'id': i.id,
                  'product_id': i.productId,
                  'description': i.productName,
                  'quantity': i.quantity,
                  'unit_price': i.unitPrice,
                  'total_amount': i.lineTotal,
                })
            .toList(),
      };

  void _materializePending() {
    for (final item in syncQueue) {
      if (item.status == SyncStatus.synced || item.payload == null) continue;
      if (item.entity == 'sale' && !sales.any((s) => s.id == item.entityId)) {
        sales = [
          _sale(_saleFromQueue(item.payload!)).copyWith(syncStatus: item.status),
          ...sales,
        ];
      } else if (item.entity == 'expense' &&
          !expenses.any((e) => e.id == item.entityId)) {
        expenses = [
          _expense(item.payload!).copyWith(syncStatus: item.status),
          ...expenses,
        ];
      } else if (item.entity == 'product' &&
          !products.any((p) => p.id == item.entityId)) {
        products = [...products, _product(item.payload!)];
      } else if (item.entity == 'customer' &&
          !customers.any((c) => c.id == item.entityId)) {
        customers = [
          ...customers,
          _customer(item.payload!).copyWith(syncStatus: item.status),
        ];
      } else if (item.entity == 'credit' &&
          !credits.any((c) => c.id == item.entityId)) {
        credits = [
          _credit(item.payload!).copyWith(syncStatus: item.status),
          ...credits,
        ];
      } else if (item.entity == 'repayment' &&
          !repayments.any((r) => r.id == item.entityId)) {
        repayments = [
          _repayment(item.payload!).copyWith(syncStatus: item.status),
          ...repayments,
        ];
      }
    }
    _recomputeCredits();
  }

  Map<String, dynamic> _saleFromQueue(Map<String, dynamic> payload) {
    return {
      ...payload,
      'sale_items': payload['items'],
    };
  }

  void _mark(String entity, String entityId, SyncStatus status) {
    if (entity == 'sale') {
      final i = sales.indexWhere((e) => e.id == entityId);
      if (i >= 0) sales = [...sales]..[i] = sales[i].copyWith(syncStatus: status);
    } else if (entity == 'expense') {
      final i = expenses.indexWhere((e) => e.id == entityId);
      if (i >= 0) {
        expenses = [...expenses]..[i] = expenses[i].copyWith(syncStatus: status);
      }
    } else if (entity == 'customer') {
      final i = customers.indexWhere((e) => e.id == entityId);
      if (i >= 0) {
        customers = [...customers]..[i] = customers[i].copyWith(syncStatus: status);
      }
    } else if (entity == 'credit') {
      final i = credits.indexWhere((e) => e.id == entityId);
      if (i >= 0) {
        credits = [...credits]..[i] = credits[i].copyWith(syncStatus: status);
      }
    } else if (entity == 'repayment') {
      final i = repayments.indexWhere((e) => e.id == entityId);
      if (i >= 0) {
        repayments = [...repayments]
          ..[i] = repayments[i].copyWith(syncStatus: status);
      }
    }
  }

  void _queueNew(
    String entity,
    String entityId,
    SyncStatus status,
    String? error,
    Map<String, dynamic>? payload,
  ) {
    syncQueue = [
      SyncQueueItem(
        id: _uuid.v4(),
        entity: entity,
        entityId: entityId,
        status: status,
        createdAt: DateTime.now(),
        error: error,
        payload: payload,
      ),
      ...syncQueue.where((e) => !(e.entity == entity && e.entityId == entityId)),
    ];
    _trimQueue();
  }

  void _queueStatus(SyncQueueItem item, SyncStatus status, String? error) {
    syncQueue = [
      for (final e in syncQueue)
        if (e.id == item.id)
          SyncQueueItem(
            id: e.id,
            entity: e.entity,
            entityId: e.entityId,
            status: status,
            createdAt: e.createdAt,
            error: error,
            payload: status == SyncStatus.synced ? null : e.payload,
          )
        else
          e,
    ];
    _trimQueue();
  }

  void _trimQueue() {
    final open = syncQueue.where((e) => e.status != SyncStatus.synced).toList();
    final done = syncQueue.where((e) => e.status == SyncStatus.synced).take(20);
    syncQueue = [...open, ...done];
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(syncQueue.map((e) => e.toJson()).toList()),
    );
  }

  bool _isOffline(Object e) {
    if (e is AuthException || e is PostgrestException) return false;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('XMLHttpRequest') ||
        s.contains('NetworkError') ||
        s.contains('Connection closed') ||
        s.contains('Connection refused');
  }

  String _msg(Object e) {
    if (e is AuthException) return e.message;
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Map<String, dynamic> _map(dynamic raw) => Map<String, dynamic>.from(raw as Map);

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  DateTime _time(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.parse(v.toString()).toLocal();
  }

  Business _business(Map<String, dynamic> j) => Business(
        id: j['id'].toString(),
        name: (j['business_name'] ?? j['name'] ?? '') as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        currency: (j['currency_code'] ?? j['currency'] ?? 'NGN') as String,
        currencySymbol: (j['currency_symbol'] ?? j['currencySymbol'] ?? '₦') as String,
        ownerId: (j['owner_user_id'] ?? j['ownerId'] ?? '') as String,
      );

  BusinessMember _member(Map<String, dynamic> j) => BusinessMember(
        id: j['id'].toString(),
        businessId: (j['business_id'] ?? j['businessId']).toString(),
        userId: (j['user_id'] ?? j['userId'] ?? '').toString(),
        role: (j['role']?.toString() == 'owner')
            ? MemberRole.owner
            : MemberRole.staff,
        displayName: (j['name'] ?? j['displayName'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        isActive: j['is_active'] as bool? ?? j['isActive'] as bool? ?? true,
      );

  Product _product(Map<String, dynamic> j) => Product(
        id: j['id'].toString(),
        businessId: (j['business_id'] ?? j['businessId']).toString(),
        name: (j['name'] ?? '') as String,
        sku: j['sku'] as String?,
        unitPrice: _num(j['selling_price'] ?? j['unitPrice']),
        costPrice: j['cost_price'] == null && j['costPrice'] == null
            ? null
            : _num(j['cost_price'] ?? j['costPrice']),
        unit: (j['unit'] as String?)?.isNotEmpty == true
            ? j['unit'] as String
            : 'pcs',
        isActive: j['is_active'] as bool? ?? j['isActive'] as bool? ?? true,
      );

  SaleItem _item(Map<String, dynamic> j) => SaleItem(
        id: j['id'].toString(),
        productId: (j['product_id'] ?? j['productId'])?.toString(),
        productName: (j['description'] ?? j['productName'] ?? '') as String,
        quantity: _num(j['quantity']),
        unitPrice: _num(j['unit_price'] ?? j['unitPrice']),
        lineTotal: _num(j['total_amount'] ?? j['lineTotal']),
      );

  Sale _sale(Map<String, dynamic> j) {
    final rawItems = (j['sale_items'] ?? j['items'] ?? []) as List;
    final total = _num(j['total_amount'] ?? j['total']);
    final statusName = (j['payment_status'] ?? j['paymentStatus'])?.toString();
    final payment = PaymentStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => PaymentStatus.paid,
    );
    final hasCredit = j['amount_on_credit'] != null || j['amountOnCredit'] != null;
    final onCredit = hasCredit
        ? _num(j['amount_on_credit'] ?? j['amountOnCredit'])
        : (payment == PaymentStatus.credit ? total : 0);
    final hasPaid = j['amount_paid'] != null || j['amountPaid'] != null;
    final paid = hasPaid ? _num(j['amount_paid'] ?? j['amountPaid']) : total - onCredit;
    final queued = j['syncStatus']?.toString();
    return Sale(
      id: j['id'].toString(),
      businessId: (j['business_id'] ?? j['businessId']).toString(),
      recordedBy: (j['recorded_by'] ?? j['recordedBy'] ?? '').toString(),
      recordedByName:
          (j['recorded_by_name'] ?? j['recordedByName'] ?? '') as String,
      total: total,
      customerId: (j['customer_id'] ?? j['customerId'])?.toString(),
      paymentStatus: payment,
      amountPaid: paid.toDouble(),
      amountOnCredit: onCredit.toDouble(),
      note: j['note'] as String?,
      soldAt: _time(j['sale_date'] ?? j['soldAt']),
      items: rawItems
          .map((e) => _item(Map<String, dynamic>.from(e as Map)))
          .toList(),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == queued,
        orElse: () => SyncStatus.synced,
      ),
    );
  }

  Expense _expense(Map<String, dynamic> j) => Expense(
        id: j['id'].toString(),
        businessId: (j['business_id'] ?? j['businessId']).toString(),
        recordedBy: (j['recorded_by'] ?? j['recordedBy'] ?? '').toString(),
        recordedByName:
            (j['recorded_by_name'] ?? j['recordedByName'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        amount: _num(j['amount']),
        categoryId: (j['category_id'] ?? j['categoryId'])?.toString(),
        categoryName: (j['category_name'] ?? j['categoryName']) as String?,
        note: j['note'] as String?,
        spentAt: _time(j['expense_date'] ?? j['spentAt']),
        syncStatus: SyncStatus.synced,
      );

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
    return salesTotal(
        from: start, to: n.add(const Duration(days: 1)), userId: userId);
  }

  double salesMonth({String? userId}) {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month, 1);
    return salesTotal(
        from: start, to: n.add(const Duration(days: 1)), userId: userId);
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

  List<Map<String, dynamic>> staffActivity({int limit = 12, String? userId}) {
    final events = <Map<String, dynamic>>[];
    for (final s in sales) {
      events.add({
        'type': 'sale',
        'title':
            'Sale · ${s.items.map((i) => i.productName).take(2).join(', ')}',
        'amount': s.total,
        'by': s.recordedByName,
        'userId': s.recordedBy,
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
        'userId': e.recordedBy,
        'at': e.spentAt,
        'id': e.id,
      });
    }
    for (final c in credits) {
      events.add({
        'type': 'credit',
        'title': 'Credit · ${c.description}',
        'amount': c.originalAmount,
        'by': c.recordedByName,
        'userId': c.recordedBy,
        'at': c.creditDate,
        'id': c.id,
      });
    }
    for (final r in repayments) {
      final credit = creditById(r.creditId);
      events.add({
        'type': 'repayment',
        'title': 'Repayment · ${credit?.description ?? 'Credit'}',
        'amount': r.amount,
        'by': r.recordedByName,
        'userId': r.recordedBy,
        'at': r.repaymentDate,
        'id': r.id,
      });
    }
    final filtered = userId == null
        ? events
        : events.where((e) => e['userId'] == userId).toList();
    filtered.sort(
        (a, b) => (b['at'] as DateTime).compareTo(a['at'] as DateTime));
    return filtered.take(limit).toList();
  }

  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  CustomerCredit? creditById(String? id) {
    if (id == null) return null;
    for (final c in credits) {
      if (c.id == id) return c;
    }
    return null;
  }

  String customerName(String? id) => customerById(id)?.name ?? 'Customer';

  int outstandingKobo({String? customerId}) {
    var total = 0;
    for (final c in credits) {
      if (customerId != null && c.customerId != customerId) continue;
      total += moneyToKobo(c.outstandingAmount);
    }
    return total;
  }

  int get customersOwing {
    final ids = <String>{};
    for (final c in credits) {
      if (moneyToKobo(c.outstandingAmount) > 0) ids.add(c.customerId);
    }
    return ids.length;
  }

  List<CustomerCredit> openCredits({String? customerId}) {
    final list = credits
        .where((c) =>
            moneyToKobo(c.outstandingAmount) > 0 &&
            (customerId == null || c.customerId == customerId))
        .toList()
      ..sort((a, b) => b.creditDate.compareTo(a.creditDate));
    return list;
  }

  Future<Customer?> saveCustomer({
    String? id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? note,
  }) async {
    lastError = null;
    if (business == null || currentUser == null) {
      lastError = 'Sign in first';
      notifyListeners();
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      lastError = 'Customer name is required';
      notifyListeners();
      return null;
    }
    final existing = id == null ? null : customerById(id);
    if (existing != null &&
        !isOwner &&
        existing.syncStatus == SyncStatus.synced) {
      lastError = 'Only the owner can edit customers';
      notifyListeners();
      return null;
    }
    final customer = Customer(
      id: existing?.id ?? _uuid.v4(),
      businessId: business!.id,
      name: trimmed,
      phone: _blank(phone),
      email: _blank(email),
      address: _blank(address),
      note: _blank(note),
      createdAt: existing?.createdAt ?? DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    final i = customers.indexWhere((c) => c.id == customer.id);
    customers = i >= 0
        ? ([...customers]..[i] = customer)
        : [...customers, customer];
    customers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    final payload = _customerPayload(customer);
    final status = await _attempt(
      entity: 'customer',
      entityId: customer.id,
      payload: payload,
      op: () => _pushCustomer(payload),
    );
    final saved = customer.copyWith(syncStatus: status);
    final idx = customers.indexWhere((c) => c.id == customer.id);
    if (idx >= 0) customers = [...customers]..[idx] = saved;
    notifyListeners();
    return saved;
  }

  Future<CustomerCredit?> addCredit({
    required String customerId,
    required String description,
    required double amount,
    DateTime? creditDate,
    DateTime? dueDate,
    String? note,
    String? saleId,
  }) async {
    lastError = null;
    if (business == null || currentUser == null) {
      lastError = 'Sign in first';
      notifyListeners();
      return null;
    }
    final desc = description.trim();
    final kobo = moneyToKobo(amount);
    if (desc.isEmpty) {
      lastError = 'Description is required';
      notifyListeners();
      return null;
    }
    if (kobo <= 0) {
      lastError = 'Enter an amount greater than 0';
      notifyListeners();
      return null;
    }
    if (customerById(customerId) == null) {
      lastError = 'Choose a customer';
      notifyListeners();
      return null;
    }
    final when = creditDate ?? DateTime.now();
    final credit = CustomerCredit(
      id: _uuid.v4(),
      businessId: business!.id,
      customerId: customerId,
      saleId: saleId,
      recordedBy: currentUser!.id,
      recordedByName: currentUser!.fullName,
      description: desc,
      originalAmount: koboToMoney(kobo),
      outstandingAmount: koboToMoney(kobo),
      creditDate: when,
      dueDate: dueDate,
      status: CreditStatus.unpaid,
      note: _blank(note),
      syncStatus: SyncStatus.pending,
    );
    credits = [credit, ...credits];
    notifyListeners();
    final payload = _creditPayload(credit, asNew: true);
    final customerPending =
        customerById(customerId)?.syncStatus == SyncStatus.pending;
    final salePending =
        saleId != null && saleById(saleId)?.syncStatus == SyncStatus.pending;
    final SyncStatus status;
    if (customerPending || salePending) {
      status = SyncStatus.pending;
      _queueNew('credit', credit.id, status, null, payload);
      await _persistQueue();
    } else {
      status = await _attempt(
        entity: 'credit',
        entityId: credit.id,
        payload: payload,
        op: () => _pushCredit(payload),
      );
    }
    final saved = credit.copyWith(syncStatus: status);
    final idx = credits.indexWhere((c) => c.id == credit.id);
    if (idx >= 0) credits = [...credits]..[idx] = saved;
    notifyListeners();
    return saved;
  }

  /// Rejects overpayment and already-paid credits against the balance known
  /// on this device, including repayments that are still queued.
  String? repaymentError(CustomerCredit credit, double amount) {
    if (credit.status == CreditStatus.paid ||
        moneyToKobo(credit.outstandingAmount) <= 0) {
      return 'This credit is already paid';
    }
    final kobo = moneyToKobo(amount);
    if (kobo <= 0) return 'Enter an amount greater than 0';
    if (kobo > moneyToKobo(credit.outstandingAmount)) {
      return 'Amount is more than the outstanding balance';
    }
    return null;
  }

  Future<CreditRepayment?> recordRepayment({
    required String creditId,
    required double amount,
    DateTime? repaymentDate,
    String? note,
  }) async {
    lastError = null;
    final credit = creditById(creditId);
    if (business == null || currentUser == null || credit == null) {
      lastError = 'Credit was not found';
      notifyListeners();
      return null;
    }
    final error = repaymentError(credit, amount);
    if (error != null) {
      lastError = error;
      notifyListeners();
      return null;
    }
    final kobo = moneyToKobo(amount);
    final repayment = CreditRepayment(
      id: _uuid.v4(),
      businessId: business!.id,
      customerId: credit.customerId,
      creditId: credit.id,
      recordedBy: currentUser!.id,
      recordedByName: currentUser!.fullName,
      amount: koboToMoney(kobo),
      repaymentDate: repaymentDate ?? DateTime.now(),
      note: _blank(note),
      syncStatus: SyncStatus.pending,
    );
    repayments = [repayment, ...repayments];
    _recomputeCredits();
    notifyListeners();
    final payload = _repaymentPayload(repayment);
    final waiting = credit.syncStatus == SyncStatus.pending ||
        customerById(credit.customerId)?.syncStatus == SyncStatus.pending;
    final SyncStatus status;
    if (waiting) {
      status = SyncStatus.pending;
      _queueNew('repayment', repayment.id, status, null, payload);
      await _persistQueue();
    } else {
      status = await _attempt(
        entity: 'repayment',
        entityId: repayment.id,
        payload: payload,
        op: () => _pushRepayment(payload),
      );
    }
    final saved = repayment.copyWith(syncStatus: status);
    final idx = repayments.indexWhere((r) => r.id == repayment.id);
    if (idx >= 0) repayments = [...repayments]..[idx] = saved;
    notifyListeners();
    return saved;
  }

  int _entityRank(String entity) {
    switch (entity) {
      case 'customer':
        return 0;
      case 'product':
        return 1;
      case 'sale':
        return 2;
      case 'expense':
        return 3;
      case 'credit':
        return 4;
      case 'repayment':
        return 5;
      default:
        return 9;
    }
  }

  String? _blank(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Map<String, dynamic> _customerPayload(Customer customer) => {
        'id': customer.id,
        'business_id': customer.businessId,
        'name': customer.name,
        'phone': customer.phone,
        'email': customer.email,
        'address': customer.address,
        'note': customer.note,
      };

  Map<String, dynamic> _creditPayload(CustomerCredit credit, {bool asNew = false}) => {
        'id': credit.id,
        'business_id': credit.businessId,
        'customer_id': credit.customerId,
        'sale_id': credit.saleId,
        'recorded_by': credit.recordedBy,
        'recorded_by_name': credit.recordedByName,
        'description': credit.description,
        'original_amount': koboToNumeric(moneyToKobo(credit.originalAmount)),
        'outstanding_amount': koboToNumeric(
          moneyToKobo(asNew ? credit.originalAmount : credit.outstandingAmount),
        ),
        'credit_date': credit.creditDate.toUtc().toIso8601String(),
        'due_date': _dateOnly(credit.dueDate),
        'status': asNew ? CreditStatus.unpaid.name : credit.status.name,
        'note': credit.note,
      };

  Map<String, dynamic> _repaymentPayload(CreditRepayment repayment) => {
        'id': repayment.id,
        'business_id': repayment.businessId,
        'customer_id': repayment.customerId,
        'credit_id': repayment.creditId,
        'recorded_by': repayment.recordedBy,
        'recorded_by_name': repayment.recordedByName,
        'amount': koboToNumeric(moneyToKobo(repayment.amount)),
        'repayment_date': repayment.repaymentDate.toUtc().toIso8601String(),
        'note': repayment.note,
      };

  Future<void> _pushCustomer(Map<String, dynamic> payload) async {
    final db = _db!;
    final existing = await db
        .from('customers')
        .select('id')
        .eq('id', payload['id'])
        .maybeSingle();
    if (existing == null) {
      await db.from('customers').insert(payload);
      return;
    }
    if (!isOwner) return;
    await db.from('customers').update({
      'name': payload['name'],
      'phone': payload['phone'],
      'email': payload['email'],
      'address': payload['address'],
      'note': payload['note'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', payload['id']);
  }

  Future<void> _pushCredit(Map<String, dynamic> payload) async {
    final db = _db!;
    final existing = await db
        .from('customer_credits')
        .select('id')
        .eq('id', payload['id'])
        .maybeSingle();
    if (existing == null) {
      final row = Map<String, dynamic>.from(payload);
      row['outstanding_amount'] = row['original_amount'];
      row['status'] = 'unpaid';
      await db.from('customer_credits').insert(row);
    }
  }

  Future<void> _pushRepayment(Map<String, dynamic> payload) async {
    final db = _db!;
    final existing = await db
        .from('credit_repayments')
        .select('id')
        .eq('id', payload['id'])
        .maybeSingle();
    if (existing == null) {
      await db.from('credit_repayments').insert(payload);
    }
  }

  void _recomputeCredits() {
    credits = [for (final credit in credits) _balanced(credit)];
  }

  CustomerCredit _balanced(CustomerCredit credit) {
    final original = moneyToKobo(credit.originalAmount);
    var repaid = 0;
    for (final repayment in repayments) {
      if (repayment.creditId == credit.id) {
        repaid += moneyToKobo(repayment.amount);
      }
    }
    final outstanding = original - repaid;
    final safe = outstanding < 0 ? 0 : outstanding;
    final status = safe <= 0
        ? CreditStatus.paid
        : safe >= original
            ? CreditStatus.unpaid
            : CreditStatus.partial;
    return credit.copyWith(
      outstandingAmount: koboToMoney(safe),
      status: status,
    );
  }

  Customer _customer(Map<String, dynamic> j) => Customer(
        id: j['id'].toString(),
        businessId: (j['business_id'] ?? j['businessId']).toString(),
        name: (j['name'] ?? '') as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        note: j['note'] as String?,
        createdAt: _time(j['created_at'] ?? j['createdAt']),
        syncStatus: SyncStatus.synced,
      );

  CustomerCredit _credit(Map<String, dynamic> j) => CustomerCredit(
        id: j['id'].toString(),
        businessId: (j['business_id'] ?? j['businessId']).toString(),
        customerId: (j['customer_id'] ?? j['customerId']).toString(),
        saleId: (j['sale_id'] ?? j['saleId'])?.toString(),
        recordedBy: (j['recorded_by'] ?? j['recordedBy'] ?? '').toString(),
        recordedByName:
            (j['recorded_by_name'] ?? j['recordedByName'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        originalAmount: _num(j['original_amount'] ?? j['originalAmount']),
        outstandingAmount:
            _num(j['outstanding_amount'] ?? j['outstandingAmount']),
        creditDate: _time(j['credit_date'] ?? j['creditDate']),
        dueDate: _parseDate(j['due_date'] ?? j['dueDate']),
        status: CreditStatus.values.firstWhere(
          (e) => e.name == (j['status']?.toString() ?? ''),
          orElse: () => CreditStatus.unpaid,
        ),
        note: j['note'] as String?,
        syncStatus: SyncStatus.synced,
      );

  CreditRepayment _repayment(Map<String, dynamic> j) => CreditRepayment(
        id: j['id'].toString(),
        businessId: (j['business_id'] ?? j['businessId']).toString(),
        customerId: (j['customer_id'] ?? j['customerId']).toString(),
        creditId: (j['credit_id'] ?? j['creditId']).toString(),
        recordedBy: (j['recorded_by'] ?? j['recordedBy'] ?? '').toString(),
        recordedByName:
            (j['recorded_by_name'] ?? j['recordedByName'] ?? '') as String,
        amount: _num(j['amount']),
        repaymentDate: _time(j['repayment_date'] ?? j['repaymentDate']),
        note: j['note'] as String?,
        syncStatus: SyncStatus.synced,
      );

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isEmpty) return null;
    final parsed = DateTime.parse(raw.length == 10 ? '${raw}T00:00:00' : raw);
    return parsed.toLocal();
  }
}

class _StaffSignup {
  final String? userId;
  final bool confirmed;
  final bool existing;
  const _StaffSignup({this.userId, this.confirmed = false}) : existing = false;
  const _StaffSignup.existing()
      : userId = null,
        confirmed = false,
        existing = true;
}
