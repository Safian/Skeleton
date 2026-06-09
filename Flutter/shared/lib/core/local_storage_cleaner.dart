import 'local_storage_cleaner_stub.dart'
    if (dart.library.html) 'local_storage_cleaner_web.dart';

void clearSupabaseLocalStorage() {
  clearSupabaseLocalStorageImpl();
}
