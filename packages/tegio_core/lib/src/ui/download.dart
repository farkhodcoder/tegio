// CSV faqat brauzerda yuklanadi; testlar VM'da ishlaydi, u yerda package:web kompilyatsiya bo'lmaydi.
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
