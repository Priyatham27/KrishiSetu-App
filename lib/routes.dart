// lib/routes.dart
//
// Centralized route names and generator for KrishiSetu.
// Keeps navigation in one place and performs argument checking for each route.
//
// Replace or extend route names as you add new screens.

import 'dart:io';

import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'screens/role_select.dart';
import 'screens/login_demo.dart';
import 'screens/farmer_dashboard.dart';
import 'screens/buyer_feed.dart';
import 'screens/add_listing.dart';
import 'screens/edit_listing.dart';
import 'screens/listing_detail.dart';
import 'screens/offers_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/farmer_profile_screen.dart';
import 'screens/buyer_profile_screen.dart';

import 'models/listing.dart';

/// All route names used across the app.
class Routes {
  static const String splash = '/';
  static const String roleSelect = '/role-select';
  static const String loginDemo = '/login-demo';
  static const String farmerDashboard = '/farmer-dashboard';
  static const String buyerFeed = '/buyer-feed';
  static const String addListing = '/add-listing';
  static const String editListing = '/edit-listing';
  static const String listingDetail = '/listing-detail';
  static const String offers = '/offers';
  static const String transactions = '/transactions';
  static const String farmerProfile = '/farmer-profile';
  static const String buyerProfile = '/buyer-profile';

  /// Demo-only local screenshot path (file uploaded in conversation).
  /// On-device this file path will probably not exist; this is only for development/debug in the web environment used earlier.
  static const String demoScreenshotLocalPath = '/mnt/data/3092cec7-47a1-481d-a69d-d5aee694bb52.png';
}

/// Generates MaterialPageRoute objects and validates arguments where necessary.
class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case Routes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case Routes.roleSelect:
        return MaterialPageRoute(builder: (_) => const RoleSelectScreen());

      case Routes.loginDemo:
        return MaterialPageRoute(builder: (_) => const LoginDemoScreen());

      case Routes.farmerDashboard:
        return MaterialPageRoute(builder: (_) => const FarmerDashboardScreen());

      case Routes.buyerFeed:
        return MaterialPageRoute(builder: (_) => const BuyerFeedScreen());

      case Routes.addListing:
        return MaterialPageRoute(builder: (_) => const AddListingScreen());

      case Routes.editListing:
      // expects args: Listing
        if (args is Listing) {
          return MaterialPageRoute(builder: (_) => EditListingScreen(listing: args));
        }
        return _errorRoute('EditListing requires a Listing argument.');

      case Routes.listingDetail:
      // expects args: Listing
        if (args is Listing) {
          return MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: args));
        }
        return _errorRoute('ListingDetail requires a Listing argument.');

      case Routes.offers:
      // optionally accept a Listing; if null the Offers screen should handle it
        if (args == null) {
          return MaterialPageRoute(builder: (_) => const OffersScreen());
        }
        if (args is Listing) {
          return MaterialPageRoute(builder: (_) => OffersScreen(listing: args));
        }
        return _errorRoute('Offers route expects a Listing or nothing.');

      case Routes.transactions:
        return MaterialPageRoute(builder: (_) => const TransactionScreen());

      case Routes.farmerProfile:
        return MaterialPageRoute(builder: (_) => const FarmerProfileScreen());

      case Routes.buyerProfile:
        return MaterialPageRoute(builder: (_) => const BuyerProfileScreen());

      default:
        return _errorRoute('No route defined for ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Navigation error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

/// Small navigator helpers (convenience).
class Nav {
  static Future<T?> pushNamed<T extends Object?>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(routeName, arguments: arguments);
  }

  static void pop(BuildContext context, [Object? result]) {
    Navigator.of(context).pop(result);
  }
}

/// Debug screen to display a local demo image file (only useful in your dev environment).
/// If the file does not exist on device, the screen shows a friendly message.
class DemoScreenshotScreen extends StatelessWidget {
  final String path;
  const DemoScreenshotScreen({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Screenshot')),
      body: Center(
        child: FutureBuilder<bool>(
          future: file.exists(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
            if (!(snap.data ?? false)) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Demo screenshot not found at:\n$path\n\nThis debug screen is for developer preview only.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Image.file(file, fit: BoxFit.contain);
          },
        ),
      ),
    );
  }
}
