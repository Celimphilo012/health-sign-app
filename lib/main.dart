import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'services/permission_service.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/shared/conversation_history_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/nurse/nurse_home_screen.dart';
import 'screens/shared/gesture_demo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
  );

  // Request permissions early
  await PermissionService().requestAll();

  runApp(const HealthSignApp());
}

class HealthSignApp extends StatelessWidget {
  const HealthSignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
      ],
      child: MaterialApp(
        title: 'HealthSign',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          primaryColor: const Color(0xFF00BFA5),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00BFA5),
            secondary: Color(0xFF1DE9B6),
            surface: Color(0xFF161B22),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/patient-home': (_) => const PatientHomeScreen(),
          '/nurse-home': (_) => const NurseHomeScreen(),
          '/history': (_) => const ConversationHistoryScreen(),
          '/gesture-demo': (_) => const GestureDemoScreen(),
        },
      ),
    );
  }
}
