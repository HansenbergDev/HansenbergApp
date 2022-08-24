import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tilmeldings_system/Models/Enlistment.dart';
import 'package:tilmeldings_system/Models/Menu.dart';
import 'package:tilmeldings_system/Models/TokenNotifier.dart';
import 'package:tilmeldings_system/Utilities/Clients/EnlistmentClient.dart';
import 'package:tilmeldings_system/Utilities/Clients/MenuClient.dart';
import 'package:tilmeldings_system/Utilities/Storage/MenuStorage.dart';
import 'package:tilmeldings_system/Utilities/Storage/EnlistmentStorage.dart';
import 'package:tilmeldings_system/Utilities/util.dart';
import 'package:tilmeldings_system/Widgets/ActivityIndicatorWithTitle.dart';
import 'package:tilmeldings_system/Widgets/IconCupertinoButton.dart';
import 'package:week_of_year/date_week_extensions.dart';

import '../Widgets/MenuTile.dart';

class StudentWeekPage extends StatefulWidget {
  const StudentWeekPage({
    Key? key,
    required this.mondayOfWeek,
    required this.menuStorage,
    required this.enlistmentStorage,
    required this.menuClient,
    required this.enlistmentClient
  }) : super(key: key);

  final DateTime mondayOfWeek;
  final MenuStorage menuStorage;
  final EnlistmentStorage enlistmentStorage;
  final MenuClient menuClient;
  final EnlistmentClient enlistmentClient;

  @override
  State<StudentWeekPage> createState() => _StudentWeekPageState();
}

class _StudentWeekPageState extends State<StudentWeekPage> {

  Menu _menu = const Menu(monday: "", tuesday: "", wednesday: "", thursday: "");
  List<EnlistmentStates> _enlistments = [];
  bool _expanded = false;
  bool _enlistmentSent = false;

  Future<Enlistment> _loadEnlistment() {
    return widget.enlistmentStorage.readEnlistment();
  }

  Future<Enlistment?> _getEnlistment(String token) {
    return widget.enlistmentClient.getEnlistment(
        widget.mondayOfWeek.year,
        widget.mondayOfWeek.weekOfYear,
        token);
  }

  Future<File> _saveEnlistment(Enlistment enlistment) {
    return widget.enlistmentStorage.writeEnlistment(enlistment);
  }

  Future<void> _sendEnlistment(Enlistment enlistment, String token) {
    return widget.enlistmentClient.createEnlistment(
        widget.mondayOfWeek.year,
        widget.mondayOfWeek.weekOfYear,
        enlistment,
        token
    );
  }

  Future<void> _updateEnlistment(Enlistment enlistment, String token) {
    return widget.enlistmentClient.updateEnlistment(
      widget.mondayOfWeek.year,
      widget.mondayOfWeek.weekOfYear,
      enlistment,
      token
    );
  }

  Future<Enlistment?> _fetchEnlistment(String token) async {
    Enlistment? enlistment;

    bool enlistmentExists = await widget.enlistmentStorage.enlistmentExists();

    if (enlistmentExists) {
      enlistment = await _loadEnlistment();
    }
    else {
      enlistment = await _getEnlistment(token);

      if (enlistment != null) {
        _saveEnlistment(enlistment);
      }
    }

    return enlistment;
  }

  Future<Menu> _loadMenu() {
    return widget.menuStorage.readMenu();
  }

  Future<Menu?> _getMenu() {
    return widget.menuClient.getMenu(
        widget.mondayOfWeek.year,
        widget.mondayOfWeek.weekOfYear
    );
  }

  Future<File> _saveMenu(Menu menu) {
    return widget.menuStorage.writeMenu(menu);
  }

  Future<Menu?> _fetchMenu() async {
    Menu? menu;

    bool menuExists = await widget.menuStorage.menuExists();

    if (menuExists) {
      menu = await _loadMenu();
    }
    else {
      menu = await _getMenu();

      if (menu != null) {
        _saveMenu(menu);
      }
    }

    return menu;
  }

  Future<bool> _fetchData(String token) async {
    Menu? menu;
    Enlistment? enlistment;

    menu = await _fetchMenu();

    if (menu != null) {
      _menu = menu;
      enlistment = await _fetchEnlistment(token);

      if (enlistment != null) {
        _enlistmentSent = true;
        _enlistments = enlistment
            .map((e) => e ? EnlistmentStates.enlisted : EnlistmentStates.rejected)
            .toList();
      }
      else {
        _enlistments = List<EnlistmentStates>.generate(5, (index) => index < 4 ? EnlistmentStates.none : EnlistmentStates.rejected);
      }
    }
    else {
      _menu = const Menu(monday: "", tuesday: "", wednesday: "", thursday: "");
    }

    return true;
  }

  void _sendData(String token) async {
    setState(() {
      _enlistmentSent = true;
    });
    return await _sendEnlistment(Enlistment.fromEnlistmentStates(_enlistments), token);
  }

  void _updateData(String token) async {
    return await _updateEnlistment(Enlistment.fromEnlistmentStates(_enlistments), token);
  }

  void _navigateToNextWeek() {
    int week = widget.mondayOfWeek.weekOfYear + 1;
    _navigateToWeek(week);
  }

  void _navigateToPreviousWeek() {
    int week = widget.mondayOfWeek.weekOfYear - 1;
    _navigateToWeek(week);
  }

  void _navigateToWeek(int week) {
    Navigator.of(context).pushReplacementNamed('$week');
  }


  void _makeEnlistmentChoice(int index, EnlistmentStates choice) async {
    setState(() {
      _enlistments[index] = choice;
    });

    if (!_enlistments.any((element) => element == EnlistmentStates.none)) {
      Enlistment enlistment = Enlistment.fromEnlistmentStates(_enlistments);
      await _saveEnlistment(enlistment);
    }
  }

  bool get _enlistmentIsValid {
    return _enlistments
        .take(4)
        .any((element) => element == EnlistmentStates.none)
        ? false : true;
  }

  void Function()? _enlistButtonPress(String token) {
    if (_enlistmentSent) {
      return () => _updateData(token);
    }
    else if (_enlistmentIsValid){
      return () => _sendData(token);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    var dates = List<DateTime>.generate(
        5, (index) => widget.mondayOfWeek.add(Duration(days: index)));

    String token = context.select<TokenNotifier, String>((notifier) => notifier.token!);

    return FutureBuilder<bool>(
        builder: (BuildContext futureContext, AsyncSnapshot<bool> snapshot) {
          Widget child;

          if (snapshot.hasData) {

            if (_menu.monday.isEmpty ||
                _menu.tuesday.isEmpty ||
                _menu.wednesday.isEmpty ||
                _menu.thursday.isEmpty) {
              child = const Center(
                child: Text("Ingen menu tilgængelig for denne uge"),
              );
            }
            else {
              child = CupertinoScrollbar(
                  thumbVisibility: true,
                  thickness: 6.0,
                  thicknessWhileDragging: 10.0,
                  radius: const Radius.circular(34.0),
                  child: Center(
                    child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: ListView.builder(
                          itemCount: 8,
                          itemBuilder: (BuildContext context, int index) {
                            switch (index) {
                              case 0:
                              case 1:
                              case 2:
                              case 3:
                                return MenuTile(
                                  dateString:
                                  "${dayNumberInWeekToDayString(dates[index].weekday)} d. ${dates[index].day} ${monthNumberToMonthString(dates[index].month)}",
                                  menuText: _menu.toList()[index],
                                  enlistmentState: _enlistments[index],
                                  enlistForDinner: () => _makeEnlistmentChoice(index, EnlistmentStates.enlisted),
                                  rejectDinner: () => _makeEnlistmentChoice(index, EnlistmentStates.rejected),
                                );
                              case 4:
                                if (!_expanded) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                                    padding: const EdgeInsets.all(15.0),
                                    decoration: const BoxDecoration(
                                        color: CupertinoColors.systemBackground,
                                        borderRadius: BorderRadius.all(Radius.circular(15))),
                                    child: GestureDetector(
                                        onTap: () => setState(() {
                                          _expanded = true;
                                        }),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: const [
                                            Text(
                                              // TODO: Bedre titel på denne
                                              "Fredag (Frivilligt)",
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Icon(
                                              CupertinoIcons.chevron_down,
                                              color: CupertinoColors.black,
                                              size: 30,
                                            )
                                          ],
                                        )
                                    ),
                                  );
                                }
                                else {
                                  return MenuTile(
                                    dateString:
                                    "${dayNumberInWeekToDayString(dates[index].weekday)} d. ${dates[index].day} ${monthNumberToMonthString(dates[index].month)}",
                                    menuText: "Der er ikke en menu for fredag, da dette er et særtilbud",
                                    enlistmentState: _enlistments[index],
                                    enlistForDinner: () => _makeEnlistmentChoice(index, EnlistmentStates.enlisted),
                                    rejectDinner: () => _makeEnlistmentChoice(index, EnlistmentStates.rejected),
                                  );
                                }
                              case 5:
                                return const SizedBox(
                                  height: 20,
                                );
                              case 6:
                                return IconCupertinoButtonFilled(
                                    onPressed: _enlistButtonPress(token),
                                    text: _enlistmentSent ? "Opdater tilmelding" : "Send tilmelding",
                                    icon: CupertinoIcons.paperplane);
                              case 7:
                                return const SizedBox(
                                  height: 30,
                                );
                              default:
                                return const Text("This should not show up");
                            }
                          },
                        )),
                  ));
            }
          }
          else if (snapshot.hasError) {
            child = Center(child: Text("An error happened here: ${snapshot.error}"));
          }
          else {
            child = const ActivityIndicatorWithTitle();
          }

          return CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                leading: CupertinoButton(
                  onPressed: () => _navigateToPreviousWeek(),
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.arrow_left_circle_fill),
                ),
                middle: Text("Uge ${widget.mondayOfWeek.weekOfYear}"),
                trailing: CupertinoButton(
                    onPressed: () => _navigateToNextWeek(),
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.arrow_right_circle_fill)),
              ),
              child: GestureDetector(
                // TODO: Check om det her gør som forventet (på en telefon...)
                onHorizontalDragEnd: (details) => {
                  if (details.primaryVelocity! > 0) {
                    _navigateToPreviousWeek()
                  }
                  else if (details.primaryVelocity! < 0){
                    _navigateToNextWeek()
                  }
                },
                child: child,
              ));
        },
      future: (_enlistments.isEmpty || _menu.any((element) => element.isEmpty)) ? _fetchData(token) : null,
    );
  }
}
