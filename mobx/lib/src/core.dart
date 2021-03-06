import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:mobx/mobx.dart';
import 'package:mobx/src/interceptable.dart';
import 'package:mobx/src/listenable.dart';
import 'package:mobx/src/utils.dart';

part 'core/action.dart';
part 'core/atom.dart';
part 'core/derivation.dart';
part 'core/reaction.dart';
part 'core/reaction_helper.dart';
part 'core/context.dart';
part 'core/observable.dart';
part 'core/computed.dart';
part 'core/observable_list_mixin.dart';

class MobXException implements Exception {
  MobXException(this.message);

  String message;
}

class MobXCaughtException implements Exception {
  MobXCaughtException(exception) : _exception = exception;

  Object _exception;
}
