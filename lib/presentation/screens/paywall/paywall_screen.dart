import 'package:aezakmi_price_service/aezakmi_price_service.dart';
import 'package:apphud/apphud.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class PaywallScreen extends StatefulWidget {
  final bool? isTrial;

  const PaywallScreen({super.key, this.isTrial = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final PaywallController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaywallController(isTrial: widget.isTrial ?? false);
    Apphud.paywallShown(AezakmiPriceService().paywallGlobal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onClose() async {
    if (!isSubscribed.value) {
      Apphud.paywallClosed(AezakmiPriceService().paywallGlobal);
    }

    if (mounted) {
      final appSettings = AppSettingsService.instance;
      if (!appSettings.isTutorialSkipped) {
        Navigator.pushReplacementNamed(context, AppRoutes.tutorial);
        return;
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final state = _controller.state;
          final priceAndDuration = state.isTrial
              ? weekTrialProduct.getPriceAndDurationPlus()
              : weekProduct.getPriceAndDuration(omitOneUnit: true);
          final duration = weekTrialProduct.getTrialPeriod();

          return SafeArea(
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
                        isLoading: state.isLoading,
                        price: priceAndDuration,
                        duration: duration ?? '',
                        value: state.isTrial,
                        onChanged: (value) => _controller.switchTrial(value),
                        onPressed: () async {
                          await _controller.purchase();
                          _onClose();
                        },
                      ),

                      TermsGroup(
                        onRestore: () {
                          _controller.restore();
                          _onClose();
                        },
                      ),
                    ],
                  ),
                ),

                state.isLoading
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
          );
        },
      ),
    );
  }
}
