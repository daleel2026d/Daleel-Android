import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// اختيار صورة من المعرض أو الكاميرا
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return file;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// رفع صورة عام في مجلد مخصص (يحاول في Supabase Storage أولاً، ثم Firebase كاحتياط)
  Future<String> uploadImage({
    required String section, // 'universities', 'scholarships', 'opportunities', 'training_centers'
    required String itemId,
    required String folder, // 'covers', 'logos', 'images', 'gallery', 'posts'
    required XFile file,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final safeId = itemId.trim().isEmpty
        ? 'new_${DateTime.now().millisecondsSinceEpoch}'
        : itemId.trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$section/$safeId/$folder/img_$timestamp.jpg';

    // 1. محاولة الرفع عبر Supabase Storage أولاً إذا كان مهيأً
    dynamic supabaseError;
    if (SupabaseService.isConfigured) {
      try {
        final client = SupabaseService.client;
        await client.storage.from('images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
        final publicUrl = client.storage.from('images').getPublicUrl(path);
        debugPrint('✅ تم رفع الصورة بنجاح إلى Supabase Storage: $publicUrl');
        return publicUrl;
      } catch (e) {
        supabaseError = e;
        debugPrint('⚠️ تعذر الرفع عبر Supabase Storage: $e');
      }
    }

    // 2. إذا فشل Supabase وفشلت Firebase، أو إذا كان Firebase غير مفعل
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'section': section,
          'itemId': safeId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (firebaseError) {
      // إذا كان Supabase مهيأ وفشل، نعرض سبب فشل Supabase لأنه النظام المستهدف
      if (supabaseError != null) {
        throw supabaseError;
      }
      rethrow;
    }
  }

  /// رفع صورة لجامعة
  Future<String> uploadUniversityImage({
    required String universityId,
    required XFile file,
    required String folder, // 'covers', 'logos', 'gallery', 'posts'
  }) =>
      uploadImage(
        section: 'universities',
        itemId: universityId,
        folder: folder,
        file: file,
      );

  /// رفع صورة لمنحة دراسية
  Future<String> uploadScholarshipImage({
    required String scholarshipId,
    required XFile file,
    required String folder, // 'covers', 'logos', 'gallery', 'posts'
  }) =>
      uploadImage(
        section: 'scholarships',
        itemId: scholarshipId,
        folder: folder,
        file: file,
      );

  /// رفع صورة لفرصة أو فعالية
  Future<String> uploadOpportunityImage({
    required String opportunityId,
    required XFile file,
    required String folder, // 'covers', 'logos', 'gallery', 'posts'
  }) =>
      uploadImage(
        section: 'opportunities',
        itemId: opportunityId,
        folder: folder,
        file: file,
      );

  /// رفع صورة لمركز تدريب
  Future<String> uploadTrainingCenterImage({
    required String centerId,
    required XFile file,
    required String folder, // 'covers', 'logos', 'gallery', 'posts'
  }) =>
      uploadImage(
        section: 'training_centers',
        itemId: centerId,
        folder: folder,
        file: file,
      );

  /// تحويل رسائل خطأ Firebase Storage إلى رسائل واضحة ومفهومة للمستخدم
  static String getFriendlyErrorMessage(dynamic e) {
    final str = e.toString();
    if (str.contains('Bucket not found') || str.contains('NoSuchBucket')) {
      return 'حاوية التخزين "images" غير موجودة في Supabase Storage. يرجى الدخول إلى Supabase > Storage وإنشاء New bucket باسم images وتفعيل خيار Public bucket.';
    }
    if (str.contains('row-level security') || str.contains('policy') || str.contains('security policy')) {
      return 'تم رفض إذن الرفع في Supabase Storage. يرجى تفعيل صلاحية الرفع (Upload Policy) لحاوية images في لوحة Supabase Storage.';
    }
    if (str.contains('object-not-found')) {
      return 'خدمة التخزين غير مفعلة، يرجى إنشاء مجلد images في Supabase Storage.';
    }
    if (str.contains('unauthorized') || str.contains('permission-denied')) {
      return 'تم رفض إذن الرفع. يرجى التحقق من أذونات التخزين في لوحة التحكم.';
    }
    if (str.contains('quota-exceeded')) {
      return 'تم تجاوز سعة التخزين المجانية في Firebase. يمكنك استخدام Supabase Storage بإنشاء Bucket باسم images وجعله Public.';
    }
    if (str.contains('network') || str.contains('unavailable')) {
      return 'تعذر الاتصال بخادم التخزين، يرجى التحقق من اتصال الإنترنت.';
    }
    return 'فشل رفع الصورة: $e';
  }
}
