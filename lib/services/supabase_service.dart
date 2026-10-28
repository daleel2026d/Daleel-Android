import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/university_model.dart';
import '../models/scholarship_model.dart';
import '../models/opportunity_model.dart';
import '../models/training_center_model.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://fzcnivrukmrkokitaupz.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6Y25pdnJ1a21ya29raXRhdXB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwOTIxNDMsImV4cCI6MjEwODY2ODE0M30.O9eEFd4TWRVsCYWrjBvCkWfc0R6JxP_tePsH_VIipnU';

  static bool get isConfigured =>
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'ضع_مفتاح_anon_هنا' &&
      !supabaseAnonKey.contains('ضع_');

  static SupabaseClient get client => Supabase.instance.client;

  /// تهيئة Supabase عند بدء التطبيق
  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        '⚠️ Supabase: لم يتم إدخال مفتاح supabaseAnonKey بعد. يرجى وضعه في lib/services/supabase_service.dart',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      debugPrint('✅ Supabase initialized successfully!');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
    }
  }

  // ================= 1. الجامعات (Universities) =================

  /// جلب قائمة الجامعات مرة واحدة
  Future<List<University>> getUniversities() async {
    if (!isConfigured) return [];
    try {
      final response = await client
          .from('universities')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = (map['id'] ?? '').toString();
        return University.fromMap(id, map);
      }).toList();
    } catch (e) {
      debugPrint('❌ Supabase getUniversities error: $e');
      return [];
    }
  }

  /// البث المباشر لتحديثات الجامعات في الوقت الحقيقي (Realtime Stream)
  Stream<List<University>> streamUniversities() {
    if (!isConfigured) return Stream.value([]);
    try {
      return client
          .from('universities')
          .stream(primaryKey: ['id'])
          .order('name', ascending: true)
          .map((rows) {
            return rows.map((row) {
              final map = Map<String, dynamic>.from(row);
              final id = (map['id'] ?? '').toString();
              return University.fromMap(id, map);
            }).toList();
          });
    } catch (e) {
      debugPrint('❌ Supabase streamUniversities error: $e');
      return Stream.value([]);
    }
  }

  // ================= 2. المنح الدراسية (Scholarships) =================

  Future<List<Scholarship>> getScholarships() async {
    if (!isConfigured) return [];
    try {
      final response = await client
          .from('scholarships')
          .select()
          .order('created_at', ascending: false);

      return (response as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = (map['id'] ?? '').toString();
        return Scholarship.fromMap(id, map);
      }).toList();
    } catch (e) {
      debugPrint('❌ Supabase getScholarships error: $e');
      return [];
    }
  }

  Stream<List<Scholarship>> streamScholarships() {
    if (!isConfigured) return Stream.value([]);
    try {
      return client
          .from('scholarships')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
            return rows.map((row) {
              final map = Map<String, dynamic>.from(row);
              final id = (map['id'] ?? '').toString();
              return Scholarship.fromMap(id, map);
            }).toList();
          });
    } catch (e) {
      debugPrint('❌ Supabase streamScholarships error: $e');
      return Stream.value([]);
    }
  }

  // ================= 3. الفرص والفعاليات (Opportunities) =================

  Future<List<Opportunity>> getOpportunities() async {
    if (!isConfigured) return [];
    try {
      final response = await client
          .from('opportunities')
          .select()
          .order('created_at', ascending: false);

      return (response as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = (map['id'] ?? '').toString();
        return Opportunity.fromMap(id, map);
      }).toList();
    } catch (e) {
      debugPrint('❌ Supabase getOpportunities error: $e');
      return [];
    }
  }

  Stream<List<Opportunity>> streamOpportunities() {
    if (!isConfigured) return Stream.value([]);
    try {
      return client
          .from('opportunities')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((rows) {
            return rows.map((row) {
              final map = Map<String, dynamic>.from(row);
              final id = (map['id'] ?? '').toString();
              return Opportunity.fromMap(id, map);
            }).toList();
          });
    } catch (e) {
      debugPrint('❌ Supabase streamOpportunities error: $e');
      return Stream.value([]);
    }
  }

  // ================= 4. مراكز التدريب (Training Centers) =================

  Future<List<TrainingCenter>> getTrainingCenters() async {
    if (!isConfigured) return [];
    try {
      final response = await client
          .from('training_centers')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = (map['id'] ?? '').toString();
        return TrainingCenter.fromMap(id, map);
      }).toList();
    } catch (e) {
      debugPrint('❌ Supabase getTrainingCenters error: $e');
      return [];
    }
  }

  Stream<List<TrainingCenter>> streamTrainingCenters() {
    if (!isConfigured) return Stream.value([]);
    try {
      return client
          .from('training_centers')
          .stream(primaryKey: ['id'])
          .order('name', ascending: true)
          .map((rows) {
            return rows.map((row) {
              final map = Map<String, dynamic>.from(row);
              final id = (map['id'] ?? '').toString();
              return TrainingCenter.fromMap(id, map);
            }).toList();
          });
    } catch (e) {
      debugPrint('❌ Supabase streamTrainingCenters error: $e');
      return Stream.value([]);
    }
  }
}
