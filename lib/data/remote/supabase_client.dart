import 'package:supabase_flutter/supabase_flutter.dart';

/// Global accessor for the Supabase client.
/// Initialized in main.dart via Supabase.initialize().
SupabaseClient get supabase => Supabase.instance.client;
