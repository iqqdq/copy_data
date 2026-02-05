import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final MainController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MainController(
      showSettingsDialog: (title, message) async {
        if (mounted) {
          SettingsDialog.show(context, title: title, message: message);
        }
      },
      navigateTo: (route, {arguments}) async {
        if (mounted) {
          Navigator.pushNamed(context, route);
        }
      },
      showToast: (message) {
        if (mounted) {
          CustomToast.showToast(context: context, message: message);
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        return Stack(
          children: [
            Scaffold(
              appBar: CustomAppBar(
                title: 'Copy data',
                automaticallyImplyLeading: false,
                actions: [
                  CustomIconButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
                    icon: SvgPicture.asset(
                      'assets/icons/setting.svg',
                      colorFilter: ColorFilter.mode(
                        AppColors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 32.0),
                    child: MainTile.send(
                      onPressed: () => _controller.handleRoleSelection(0),
                    ),
                  ),

                  MainTile.receive(
                    onPressed: () => _controller.handleRoleSelection(1),
                  ),
                ],
              ),
            ),

            if (state.showPermissionAlert)
              PermissionAlert(
                permissionStates: state.permissionStates,
                isRequestingPermission: state.isRequestingPermission,
                allPermissionsGranted: state.allPermissionsGranted,
                onNextPressed: () => _controller.requestNextPermission(),
                onNotNowPressed: () => _controller.hidePermissionAlert(),
              ),
          ],
        );
      },
    );
  }
}
