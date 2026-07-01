import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const primaryCharcoal = Color(0xFF1F2328);
  static const secondaryBurntOrange = Color(0xFFEA580C);
  static const accentCaliperRed = Color(0xFFDC2626);
  static const backgroundWarmOffWhite = Color(0xFFF5F1EA);
  static const surface = Color(0xFFFFFFFF);
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFB91C1C);
  static const text = Color(0xFF18181B);

  static const primaryContainer = Color(0xFF343A40);
  static const secondaryContainer = Color(0xFFFFE4D5);
  static const onSecondaryContainer = Color(0xFF6B2107);
  static const tertiaryContainer = Color(0xFFFDE2E2);
  static const onTertiaryContainer = Color(0xFF680C0C);
  static const successContainer = Color(0xFFDCFCE7);
  static const onSuccessContainer = Color(0xFF14532D);
  static const warningContainer = Color(0xFFFEF3C7);
  static const onWarningContainer = Color(0xFF78350F);
  static const errorContainer = Color(0xFFFEE2E2);
  static const onErrorContainer = Color(0xFF7F1D1D);
  static const surfaceContainerLow = Color(0xFFFCFAF6);
  static const surfaceContainer = Color(0xFFF5F1EA);
  static const surfaceContainerHigh = Color(0xFFEDE8E0);
  static const surfaceContainerHighest = Color(0xFFE5DFD6);
  static const outline = Color(0xFF74706A);
  static const outlineVariant = Color(0xFFD5CEC4);
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const fallback = AppSemanticColors(
    success: AppPalette.success,
    successContainer: AppPalette.successContainer,
    onSuccessContainer: AppPalette.onSuccessContainer,
    warning: AppPalette.warning,
    warningContainer: AppPalette.warningContainer,
    onWarningContainer: AppPalette.onWarningContainer,
  );

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>() ?? fallback;
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) {
      return this;
    }

    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.primaryCharcoal,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppPalette.primaryCharcoal,
          onPrimary: Colors.white,
          primaryContainer: AppPalette.primaryContainer,
          onPrimaryContainer: Colors.white,
          secondary: AppPalette.secondaryBurntOrange,
          onSecondary: Colors.white,
          secondaryContainer: AppPalette.secondaryContainer,
          onSecondaryContainer: AppPalette.onSecondaryContainer,
          tertiary: AppPalette.accentCaliperRed,
          onTertiary: Colors.white,
          tertiaryContainer: AppPalette.tertiaryContainer,
          onTertiaryContainer: AppPalette.onTertiaryContainer,
          error: AppPalette.error,
          onError: Colors.white,
          errorContainer: AppPalette.errorContainer,
          onErrorContainer: AppPalette.onErrorContainer,
          surface: AppPalette.surface,
          onSurface: AppPalette.text,
          surfaceContainerLowest: AppPalette.surface,
          surfaceContainerLow: AppPalette.surfaceContainerLow,
          surfaceContainer: AppPalette.surfaceContainer,
          surfaceContainerHigh: AppPalette.surfaceContainerHigh,
          surfaceContainerHighest: AppPalette.surfaceContainerHighest,
          outline: AppPalette.outline,
          outlineVariant: AppPalette.outlineVariant,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [AppSemanticColors.fallback],
      scaffoldBackgroundColor: AppPalette.backgroundWarmOffWhite,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        toolbarHeight: 64,
        titleSpacing: 20,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        shadowColor: colorScheme.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        elevation: 4,
        focusElevation: 5,
        hoverElevation: 5,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.secondaryContainer,
        checkmarkColor: colorScheme.onSecondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
        linearTrackColor: colorScheme.secondaryContainer,
        circularTrackColor: colorScheme.secondaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.primary,
        contentTextStyle: TextStyle(color: colorScheme.onPrimary),
        actionTextColor: AppPalette.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      iconTheme: IconThemeData(color: colorScheme.primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.secondary,
        selectionColor: colorScheme.secondaryContainer,
        selectionHandleColor: colorScheme.secondary,
      ),
    );
  }
}
