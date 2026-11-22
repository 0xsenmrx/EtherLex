import 'package:flutter/widgets.dart';

import '../../../design_system/ether/dialog.dart';

/// The one sign-out question (avatar menu, Settings, Ctrl+K). True on yes.
Future<bool> confirmSignOut(BuildContext context, {required bool sample}) => confirmAction(
      context,
      title: 'Sign out?',
      message: sample
          ? 'You will leave sample mode.'
          : 'Your token is removed from this computer. Your settings for this account stay.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
