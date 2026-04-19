import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_scope.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';

class ThrottleMeetApp extends StatefulWidget {
  const ThrottleMeetApp({super.key});

  @override
  State<ThrottleMeetApp> createState() => _ThrottleMeetAppState();
}

class _ThrottleMeetAppState extends State<ThrottleMeetApp> {
  late final AppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = AppDependencies.create();
    _dependencies.eventsController.load();
  }

  @override
  void dispose() {
    _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: _dependencies,
      child: MaterialApp(
        title: 'ThrottleMeet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: AppRoutes.eventsList,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
