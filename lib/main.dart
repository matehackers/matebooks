import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/log_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final logProvider = LogProvider();

  runZonedGuarded(
    () => runApp(MateBooksApp(logProvider: logProvider)),
    (error, stack) {
      logProvider.addLog('ERROR: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        logProvider.addLog(line);
        parent.print(zone, line);
      },
    ),
  );
}

class MateBooksApp extends StatelessWidget {
  final LogProvider logProvider;

  const MateBooksApp({super.key, required this.logProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: logProvider),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()..loadItems()),
      ],
      child: MaterialApp(
        title: 'MateBooks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const LibraryScreen(),
      ),
    );
  }
}
