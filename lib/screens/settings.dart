// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:async';
import 'dart:developer';

import 'package:mdi/mdi.dart';
import 'package:wsa_pacman/global_state.dart';
import 'package:wsa_pacman/utils/locale_utils.dart';
import 'package:wsa_pacman/widget/fluent_card.dart';
import 'package:wsa_pacman/widget/fluent_combo_box.dart';
import 'package:wsa_pacman/widget/fluent_text_box.dart';
import 'package:wsa_pacman/widget/smooth_list_view.dart';

import '/utils/string_utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class LateUpdater<E> {
  static const SETTINGS_UPDATE_TIMER = Duration(seconds:3);
  E initialValue;
  Timer? timer;
  Function(E value) callback;

  LateUpdater(this.initialValue, this.callback);
  update(E newValue) {
    initialValue = newValue;
    timer?.cancel();
    timer = Timer(SETTINGS_UPDATE_TIMER, (){if (initialValue == newValue) callback(initialValue);});
  }

  cancel() => timer?.cancel();

  instant(E newValue) {
    timer?.cancel();
    callback(newValue);
  }
}

class ScreenSettings extends StatefulWidget {
  ScreenSettings({Key? key, this.controller}) : super(key: key);
  final ScrollController? controller;

  @override
  State<StatefulWidget> createState() => ScreenSettingsState(controller: this.controller);
}

late final androidPortUpdater = LateUpdater<int>(GState.androidPort.$, (value){
  GState.androidPort..update((p0) => value)..persist();
  log("AGGIORNATO: ${GState.androidPort.$}");
});

class ScreenSettingsState extends State<ScreenSettings> {
  ScreenSettingsState({this.controller});
  final ScrollController? controller;

  static late final _localeItems = <NamedLocale>[LocaleUtils.SYSTEM_LOCALE].followedBy(LocaleUtils.supportedLocales).map((l)=>ComboboxItem(child: Text(l.name), value: l)).toList();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final locale_lang = GState.locale.of(context);
    final lang = AppLocalizations.of(context)!;
    
    const smallSpacer = SizedBox(height: 5.0);
    const spacer = SizedBox(height: 10.0);

    final autostartWSA = GState.autostartWSA.of(context);
    final installTimeout = GState.installTimeout.of(context);

    final OFF = lang.btn_switch_off;
    final ON = lang.btn_switch_on;

    return ScaffoldPage(
      header: PageHeader(title: Text(lang.screen_settings)),
      content: SmoothListView(
        padding: EdgeInsets.only(
          bottom: kPageDefaultVerticalPadding,
          left: PageHeader.horizontalPadding(context),
          right: PageHeader.horizontalPadding(context),
        ),
        children: [
          spacer,
          FluentCard(
            leading: const Icon(Mdi.networkOutline , size: 23),
            content: Text(lang.settings_port),
            trailing: SizedBox(width: 300, height: 32, child: FluentTextBox(
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  var androidPortVal = (newValue.text.isNumeric()) ? (newValue.text.length > 5 || (newValue.text.isEmpty ? 58526 : int.parse(newValue.text)) <= 65535 ? newValue : TextEditingValue(text: "65535", selection: newValue.selection)) : 
                  (oldValue.text.isNumeric() ? oldValue : TextEditingValue.empty);
                  GState.androidPortPending.$ = androidPortVal.text.isEmpty ? 58526.toString() : androidPortVal.text;
                  return androidPortVal;
                })
              ],
              maxLength: 5,
              maxLines: 1,
              maxLengthEnforced: true,
              controller: TextEditingController.fromValue(TextEditingValue(text: GState.androidPortPending.$)),
              autofocus: false,
              onChanged: (value)=>androidPortUpdater.update(value.isEmpty ? 58526 : int.parse(value)),
              enableSuggestions: false,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              prefix: const Padding(padding: EdgeInsetsDirectional.only(start: 10), child: Text("127.0.0.1 :")),
              suffix: IconButton (
                iconButtonMode: IconButtonMode.small,
                icon: const Icon(FluentIcons.reset),
                onPressed: () {GState.androidPortPending.update((_) => 58526.toString()); androidPortUpdater.instant(58526); setState((){});},
              )
            )),
          ),
          smallSpacer,
          FluentCard(
            leading: const Icon(Mdi.powerStandby , size: 23),
            content: Text(lang.settings_autostart),
            trailing: Row(children: [ConstrainedBox(constraints: const BoxConstraints(minWidth: 28.5), child: Text(autostartWSA ? ON : OFF)), ToggleSwitch(
              checked: autostartWSA,
              onChanged: (v) => GState.autostartWSA..$ = v..persist()
            )]),
          ),
          smallSpacer,
          FluentCard(
            leading: const Icon(Mdi.timerOutline, size: 23),
            content: Text(lang.settings_timeout(installTimeout == 0 ? '∞' : '$installTimeout')),
            trailing: SizedBox(width: 300, height: 32, child: FluentCard(isInner: true, content: Slider(
              min: 0,
              max: 105, 
              value: (installTimeout == 0 ? 105 : installTimeout < 15 ? 15 : installTimeout > 105 ? 105 : installTimeout).toDouble(),
              divisions: 7,
              label: installTimeout == 0 ? '∞' : '$installTimeout',
              style: SliderThemeData(
                labelBackgroundColor: theme.brightness == Brightness.dark ? const Color(0x22DDDDDD) : const Color(0x33000000)
              ),
              onChanged: (l){l = (l == 0) ? 15 : (l == 105) ? 0 : l; GState.installTimeout..$=l.toInt()..persist();},
            ))),
          ),
          smallSpacer,
          FluentCard(
            leading: const Icon(Mdi.translate , size: 23),
            content: Text(lang.settings_language),
            trailing: SizedBox(width: 300, height: 32, child: FluentCombobox<NamedLocale>(
              allowUnknown: true,
              onTap: (){}, placeholder: Text(locale_lang.name), 
              isExpanded: true,
              value: locale_lang,
              onChanged: (l){if (l != null) GState.locale..$=l..persist();},
              items: _localeItems,
            )),
          ),
        ],
      ),
    );
  }
  
}
