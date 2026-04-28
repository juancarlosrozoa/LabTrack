import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyAmLYerxbcahfqE0ht8utzzqvP0cohwBKA',
    appId:             '1:763080220060:android:fbafc98d2a5176eb673c59',
    messagingSenderId: '763080220060',
    projectId:         'labtrack-494403',
    storageBucket:     'labtrack-494403.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBpDZPW3ql0HES3wdnXcF4dfZGttKep_E8',
    appId:             '1:763080220060:ios:fc03bb4f05a4478d673c59',
    messagingSenderId: '763080220060',
    projectId:         'labtrack-494403',
    storageBucket:     'labtrack-494403.firebasestorage.app',
    iosBundleId:       'com.labtrack.labtrack',
  );
}
