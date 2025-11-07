import "package:flutter/material.dart";

class TechApp extends MaterialApp {
  final Color primary;
  final Color secondary;
  final String? fontFamily;
  final double? fontSizeFactor;

  TechApp({
    required super.title,
    required this.primary,
    required this.secondary,
    required super.themeMode,
    required super.home,
    super.debugShowCheckedModeBanner = false,
    this.fontFamily,
    this.fontSizeFactor,
    super.routes,
    super.key,
  }) : super(
         theme: ThemeData(
           useMaterial3: false,
           colorScheme: ColorScheme.light(primary: primary, secondary: secondary),
         ),
         darkTheme: ThemeData(
           useMaterial3: false,
           colorScheme: ColorScheme.dark(primary: primary, secondary: secondary),
         ),
         builder: (BuildContext context, Widget? child) {
           return Theme(
             data: Theme.of(context).copyWith(
               appBarTheme: AppBarTheme(backgroundColor: primary),
               textTheme: Theme.of(context).textTheme.apply(
                 fontSizeFactor: fontSizeFactor ?? 1.0,
                 fontFamily: fontFamily,
               ),
               scrollbarTheme: Theme.of(context).scrollbarTheme.copyWith(
                 radius: const Radius.circular(2),
                 thumbVisibility: const WidgetStatePropertyAll(true),
                 trackVisibility: const WidgetStatePropertyAll(true),
               ),
               floatingActionButtonTheme: FloatingActionButtonThemeData(
                 backgroundColor: primary,
               ),
               menuTheme: MenuThemeData(
                 style: MenuStyle(
                   backgroundColor: WidgetStateProperty.all(
                     Theme.of(context).scaffoldBackgroundColor,
                   ),
                 ),
               ),
             ),
             child: child!,
           );
         },
       );
}
