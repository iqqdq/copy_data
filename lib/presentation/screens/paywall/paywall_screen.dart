import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _value = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24.0,
              ).copyWith(top: 36.0),
              child: Column(
                children: [
                  const PaywallHeader(),

                  PaywallFooter(
                    isLoading: _isLoading, // TODO:
                    price: r'$5.99', // TODO:
                    value: _value,
                    onChanged: (value) => setState(() => _value = value),
                    onPressed: () async {
                      isSubscribed.value = true; // TODO:
                      _onClose();
                    },
                  ),

                  TermsGroup(onRestore: () {}), // TODO:
                ],
              ),
            ),

            _isLoading
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: CustomIconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/cross.svg',
                        colorFilter: ColorFilter.mode(
                          AppColors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: _onClose,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _onClose() async {
    if (!isSubscribed.value) {
      // TODO: Paywall.didClose
    }

    Navigator.canPop(context)
        ? Navigator.pop(context)
        : Navigator.pushReplacementNamed(context, AppRoutes.main);
  }
}
