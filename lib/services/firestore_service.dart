import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/university_model.dart';
import '../models/scholarship_model.dart';
import '../models/college_with_university.dart';
import '../models/opportunity_model.dart';
import '../models/training_center_model.dart';
import '../models/notification_model.dart';

import 'supabase_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ذاكرة تخزين مؤقت سريعة جداً لمنع تكرار جلب البيانات عند التنقل
  static List<University>? _cachedUniversities;

  // ===== الجامعات =====

  Stream<List<University>> getAllUniversities() {
    if (SupabaseService.isConfigured) {
      return SupabaseService().streamUniversities();
    }
    return _firestore.collection('universities').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => University.fromMap(doc.id, doc.data()))
          .toList();
      _cachedUniversities = list;
      return list;
    });
  }

  Future<List<University>> fetchUniversitiesOnce() async {
    if (_cachedUniversities != null && _cachedUniversities!.isNotEmpty) {
      return _cachedUniversities!;
    }
    if (SupabaseService.isConfigured) {
      final supaList = await SupabaseService().getUniversities();
      if (supaList.isNotEmpty) {
        _cachedUniversities = supaList;
        return supaList;
      }
    }
    final snapshot = await _firestore.collection('universities').get();
    final list = snapshot.docs
        .map((doc) => University.fromMap(doc.id, doc.data()))
        .toList();
    _cachedUniversities = list;
    return list;
  }

  Stream<University?> getUniversityById(String id) {
    return _firestore.collection('universities').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return University.fromMap(doc.id, doc.data()!);
    });
  }

  // ===== الفلترة الجديدة: كليات مطابقة =====

  static String _normalizeArabic(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  static bool _matchesTrack(String collegeCategory, String selectedTrack) {
    final normCol = _normalizeArabic(collegeCategory);
    final normTrack = _normalizeArabic(selectedTrack);

    if (normCol.isEmpty) return true; // الكلية تقبل كافة الفروع إذا لم يحدد فرع

    // إذا كانت الكلية مشتركة أو عامة لجميع الفروع
    if (normCol.contains('مشترك') ||
        normCol.contains('عام') ||
        normCol.contains('كاف') ||
        normCol.contains('الكل')) {
      return true;
    }

    if (normTrack.contains('علم')) {
      // الفرع العلمي يشمل العلمي والإحيائي والتطبيقي
      return normCol.contains('علم') ||
          normCol.contains('احيائ') ||
          normCol.contains('تطبيق');
    } else if (normTrack.contains('ادب')) {
      // الفرع الأدبي
      return normCol.contains('ادب');
    }

    return normCol.contains(normTrack);
  }

  static bool _matchesCity(String uniCity, String selectedCity) {
    if (selectedCity.isEmpty ||
        selectedCity == 'كافة المحافظات' ||
        selectedCity.toLowerCase() == 'all') {
      return true;
    }

    final normUni = _normalizeArabic(uniCity);
    final normCity = _normalizeArabic(selectedCity);

    if (normUni.isEmpty) return true;
    if (normUni.contains(normCity) || normCity.contains(normUni)) return true;

    // توافقات المدن والمحافظات العراقية
    if ((normCity.contains('نينو') || normCity.contains('موصل')) &&
        (normUni.contains('نينو') || normUni.contains('موصل'))) {
      return true;
    }
    if ((normCity.contains('بابل') || normCity.contains('حل')) &&
        (normUni.contains('بابل') || normUni.contains('حل'))) {
      return true;
    }
    if ((normCity.contains('قار') || normCity.contains('ناصر')) &&
        (normUni.contains('قار') || normUni.contains('ناصر'))) {
      return true;
    }
    if ((normCity.contains('قادس') || normCity.contains('ديوان')) &&
        (normUni.contains('قادس') || normUni.contains('ديوان'))) {
      return true;
    }
    if ((normCity.contains('ميسان') || normCity.contains('عمار')) &&
        (normUni.contains('ميسان') || normUni.contains('عمار'))) {
      return true;
    }
    if ((normCity.contains('مثن') || normCity.contains('سماو')) &&
        (normUni.contains('مثن') || normUni.contains('سماو'))) {
      return true;
    }
    if ((normCity.contains('واسط') || normCity.contains('كوت')) &&
        (normUni.contains('واسط') || normUni.contains('كوت'))) {
      return true;
    }
    if ((normCity.contains('صلاح') || normCity.contains('تكريت')) &&
        (normUni.contains('صلاح') || normUni.contains('تكريت'))) {
      return true;
    }

    return false;
  }

  static bool _matchesUniversityType(String uniType, String selectedType) {
    if (selectedType.isEmpty ||
        selectedType == 'all' ||
        selectedType == 'الكل') {
      return true;
    }

    final normUni = _normalizeArabic(uniType);
    final normSel = _normalizeArabic(selectedType);

    if (normSel.contains('حك') || normSel.contains('gov')) {
      return normUni.contains('حك') || normUni.contains('gov');
    }
    if (normSel.contains('اهل') || normSel.contains('priv')) {
      return normUni.contains('اهل') || normUni.contains('priv');
    }

    return true;
  }

  Future<List<CollegeWithUniversity>> getMatchingColleges(
    String category,
    double studentGpa, {
    String? universityType,
    String? city,
  }) async {
    final allUnis = await fetchUniversitiesOnce();

    final List<CollegeWithUniversity> results = [];
    for (final uni in allUnis) {
      if (universityType != null && !_matchesUniversityType(uni.type, universityType)) {
        continue;
      }
      if (city != null && !_matchesCity(uni.city, city)) {
        continue;
      }

      for (final college in uni.colleges) {
        final matchesBranch = _matchesTrack(college.category, category);
        final qualifiesGpa = college.minGpa == 0 || studentGpa >= college.minGpa;

        if (matchesBranch && qualifiesGpa) {
          results.add(CollegeWithUniversity(college: college, university: uni));
        }
      }
    }

    // ترتيب النتائج تنازلياً حسب الحد الأدنى للقبول (الأقرب لمعدل الطالب)
    results.sort((a, b) => b.college.minGpa.compareTo(a.college.minGpa));

    return results;
  }

  // ===== المفضلة والإعجابات =====

  Future<void> toggleFavorite(
    String uid,
    String universityId,
    bool isFavorite,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    if (isFavorite) {
      await userRef.set({
        'favorites': FieldValue.arrayRemove([universityId]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'favorites': FieldValue.arrayUnion([universityId]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleFavoriteScholarship(
    String uid,
    String scholarshipId,
    bool isSaved,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    if (isSaved) {
      await userRef.set({
        'savedScholarships': FieldValue.arrayRemove([scholarshipId]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'savedScholarships': FieldValue.arrayUnion([scholarshipId]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleFavoriteTrainingCenter(
    String uid,
    String centerId,
    bool isSaved,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    if (isSaved) {
      await userRef.set({
        'savedTrainingCenters': FieldValue.arrayRemove([centerId]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'savedTrainingCenters': FieldValue.arrayUnion([centerId]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleLikePost(
    String uid,
    String postKey,
    bool isLiked,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    if (isLiked) {
      await userRef.set({
        'likedPosts': FieldValue.arrayRemove([postKey]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'likedPosts': FieldValue.arrayUnion([postKey]),
      }, SetOptions(merge: true));
    }
  }

  Stream<DocumentSnapshot> getUserData(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ===== المنح =====

  Stream<List<Scholarship>> getAllScholarships() {
    if (SupabaseService.isConfigured) {
      return SupabaseService().streamScholarships();
    }
    return _firestore.collection('scholarships').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Scholarship.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<Scholarship>> fetchScholarshipsOnce() async {
    if (SupabaseService.isConfigured) {
      final supaList = await SupabaseService().getScholarships();
      if (supaList.isNotEmpty) return supaList;
    }
    final snapshot = await _firestore.collection('scholarships').get();
    return snapshot.docs
        .map((doc) => Scholarship.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> toggleSavedOpportunity(
    String uid,
    String opportunityId,
    bool isSaved,
  ) async {
    final userRef = _firestore.collection('users').doc(uid);
    if (isSaved) {
      await userRef.set({
        'savedOpportunities': FieldValue.arrayRemove([opportunityId]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'savedOpportunities': FieldValue.arrayUnion([opportunityId]),
      }, SetOptions(merge: true));
    }
  }

  Stream<List<Opportunity>> getAllOpportunities() {
    if (SupabaseService.isConfigured) {
      return SupabaseService().streamOpportunities();
    }
    return _firestore.collection('opportunities').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Opportunity.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<Opportunity>> fetchOpportunitiesOnce() async {
    if (SupabaseService.isConfigured) {
      final supaList = await SupabaseService().getOpportunities();
      if (supaList.isNotEmpty) return supaList;
    }
    final snapshot = await _firestore.collection('opportunities').get();
    return snapshot.docs
        .map((doc) => Opportunity.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Opportunity>> getSavedOpportunities(List<String> savedIds) {
    return getAllOpportunities().map((opportunities) {
      return opportunities
          .where((opportunity) => savedIds.contains(opportunity.id))
          .toList();
    });
  }

  Stream<List<Opportunity>> getOpportunitiesByType(String type) {
    if (SupabaseService.isConfigured) {
      return getAllOpportunities().map((opportunities) {
        return opportunities
            .where((opportunity) => opportunity.type == type)
            .toList();
      });
    }
    return _firestore
        .collection('opportunities')
        .where('type', isEqualTo: type)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Opportunity.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // ===== مراكز التدريب =====

  Stream<List<TrainingCenter>> getAllTrainingCenters() {
    if (SupabaseService.isConfigured) {
      return SupabaseService().streamTrainingCenters();
    }
    return _firestore
        .collection('training_centers')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) =>
              !doc.id.startsWith('_') &&
              doc.id != 'settings' &&
              doc.id != 'managers_settings')
          .map((doc) => TrainingCenter.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<TrainingCenter>> fetchTrainingCentersOnce() async {
    if (SupabaseService.isConfigured) {
      final supaList = await SupabaseService().getTrainingCenters();
      if (supaList.isNotEmpty) return supaList;
    }
    final snapshot = await _firestore.collection('training_centers').get();
    return snapshot.docs
        .where((doc) =>
            !doc.id.startsWith('_') &&
            doc.id != 'settings' &&
            doc.id != 'managers_settings')
        .map((doc) => TrainingCenter.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ===== إدارة لوحة التحكم (CRUD) =====

  // 1. الجامعات
  Future<void> addUniversity(Map<String, dynamic> data) async {
    _cachedUniversities = null;
    await _firestore.collection('universities').add(data);
  }

  Future<void> updateUniversity(String id, Map<String, dynamic> data) async {
    _cachedUniversities = null;
    await _firestore.collection('universities').doc(id).update(data);
  }

  Future<void> deleteUniversity(String id) async {
    _cachedUniversities = null;
    await _firestore.collection('universities').doc(id).delete();
  }

  // جلب الجامعات التي يديرها بريد معين
  Stream<List<University>> getUniversitiesManagedBy(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return Stream.value([]);
    return getAllUniversities().map((list) {
      return list
          .where((uni) => uni.managerEmail.trim().toLowerCase() == cleanEmail)
          .toList();
    });
  }

  // 2. المنح الدراسية
  Future<void> addScholarship(Map<String, dynamic> data) async {
    await _firestore.collection('scholarships').add(data);
  }

  Future<void> updateScholarship(String id, Map<String, dynamic> data) async {
    await _firestore.collection('scholarships').doc(id).update(data);
  }

  Future<void> deleteScholarship(String id) async {
    await _firestore.collection('scholarships').doc(id).delete();
  }

  // 3. الفرص والفعاليات
  Future<void> addOpportunity(Map<String, dynamic> data) async {
    await _firestore.collection('opportunities').add(data);
  }

  Future<void> updateOpportunity(String id, Map<String, dynamic> data) async {
    await _firestore.collection('opportunities').doc(id).update(data);
  }

  Future<void> deleteOpportunity(String id) async {
    await _firestore.collection('opportunities').doc(id).delete();
  }

  // 4. مراكز التدريب
  Future<void> addTrainingCenter(Map<String, dynamic> data) async {
    await _firestore.collection('training_centers').add(data);
  }

  Future<void> updateTrainingCenter(String id, Map<String, dynamic> data) async {
    await _firestore.collection('training_centers').doc(id).update(data);
  }

  Future<void> deleteTrainingCenter(String id) async {
    await _firestore.collection('training_centers').doc(id).delete();
  }

  // جلب مراكز التدريب التي يديرها بريد معين
  Stream<List<TrainingCenter>> getTrainingCentersManagedBy(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return Stream.value([]);
    return getAllTrainingCenters().map((list) {
      return list
          .where((center) => center.managerEmail.trim().toLowerCase() == cleanEmail)
          .toList();
    });
  }

  // 5. إعدادات مديري مراكز التدريب (الحد الأقصى 10 إيميلات)
  Stream<List<String>> getTrainingCenterManagersStream() {
    return _firestore
        .collection('training_centers')
        .doc('_managers_settings')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <String>[];
      final data = doc.data()!;
      final list = data['managerEmails'];
      if (list is List) {
        return list
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return <String>[];
    });
  }

  Future<List<String>> fetchTrainingCenterManagersOnce() async {
    try {
      final doc = await _firestore
          .collection('training_centers')
          .doc('_managers_settings')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final list = data['managerEmails'];
        if (list is List) {
          return list
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> saveTrainingCenterManagers(List<String> emails) async {
    final cleaned = emails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .take(10)
        .toList();

    final data = {
      'managerEmails': cleaned,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // حفظ في training_centers/_managers_settings (متوافق مع صلاحيات مراكز التدريب)
    await _firestore
        .collection('training_centers')
        .doc('_managers_settings')
        .set(data, SetOptions(merge: true));

    // مزامنة احتياطية
    try {
      await _firestore
          .collection('settings')
          .doc('training_centers')
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  // ===== نظام الإشعارات (Notifications) =====

  Stream<List<AppNotification>> getUserNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> addNotification(
    String uid,
    AppNotification notification,
  ) async {
    final docRef = notification.id.isNotEmpty
        ? _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(notification.id)
        : _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc();

    await docRef.set(notification.toMap(), SetOptions(merge: true));
  }

  Future<void> markNotificationAsRead(String uid, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .set({'isRead': true}, SetOptions(merge: true));
  }

  Future<void> markAllNotificationsAsRead(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String uid, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> clearAllNotifications(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
