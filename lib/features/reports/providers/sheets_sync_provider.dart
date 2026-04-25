import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/supabase_client.dart';

final sheetsSyncProvider =
    AsyncNotifierProvider.autoDispose<SheetsSyncNotifier, void>(
        SheetsSyncNotifier.new);

class SheetsSyncNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> sync() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.functions.invoke('sync-google-sheets');
    });
  }
}
