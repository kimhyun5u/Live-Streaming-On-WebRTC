import 'package:client/main.dart';
import 'package:client/screens/streamer_screen.dart';
import 'package:client/screens/watch_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const MyHomePage();
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'stream',
          builder: (BuildContext context, GoRouterState state) {
            return const StreamerScreen();
          },
        ),
        GoRoute(
          path: 'watch',
          builder: (BuildContext context, GoRouterState state) {
            return const WatchScreen();
          },
        ),
      ],
    ),
  ],
);
