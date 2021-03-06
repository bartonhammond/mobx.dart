part of '../core.dart';

/// A callable class that is used to dispose a [reaction], [autorun] or [when]
///
/// ```
/// var dispose = autorun((){
///   // ...
/// });
///
/// dispose(); // dispose the autorun()
/// ```
///
/// In the above code, `dispose` is of type `ReactionDisposer`.
class ReactionDisposer {
  ReactionDisposer(Reaction rxn) {
    _rxn = rxn;
  }

  Reaction _rxn;

  /// A special property that has a reference to the underlying reaction. Most
  /// of the time you won't need this, but it's good to have it for those special cases!
  /// MobX uses it internally for _unit-testing_ and other developer features like _spying_ and
  /// _tracing_.
  Reaction get $mobx => _rxn;

  /// Invoking it will dispose the underlying [reaction]
  void call() => $mobx.dispose();
}

ReactionDisposer createAutorun(
    ReactiveContext context, Function(Reaction) trackingFn,
    {String name, int delay, void Function(Object, Reaction) onError}) {
  Reaction rxn;

  final rxnName = name ?? context.nameFor('Autorun');

  if (delay == null) {
    // Use a sync-scheduler.
    rxn = Reaction(context, () {
      rxn._track(() => trackingFn(rxn));
    }, name: rxnName, onError: onError);
  } else {
    // Use a delayed scheduler.
    final scheduler = createDelayedScheduler(delay);
    var isScheduled = false;
    Timer timer;

    rxn = Reaction(context, () {
      if (!isScheduled) {
        isScheduled = true;

        if (timer != null) {
          timer.cancel();
          timer = null;
        }

        timer = scheduler(() {
          isScheduled = false;
          if (!rxn.isDisposed) {
            rxn._track(() => trackingFn(rxn));
          } else {
            timer.cancel();
          }
        });
      }
    }, name: rxnName, onError: onError);
  }

  rxn.schedule();
  return ReactionDisposer(rxn);
}

ReactionDisposer createReaction<T>(ReactiveContext context,
    T Function(Reaction) predicate, void Function(T) effect,
    {String name,
    int delay,
    bool fireImmediately,
    void Function(Object, Reaction) onError}) {
  Reaction rxn;

  final rxnName = name ?? context.nameFor('Reaction');

  final effectAction =
      action((T value) => effect(value), name: '$rxnName-effect');

  final runSync = delay == null;
  final scheduler = delay != null ? createDelayedScheduler(delay) : null;

  var firstTime = true;
  T value;

  void reactionRunner() {
    if (rxn.isDisposed) {
      return;
    }

    var changed = false;

    rxn._track(() {
      final nextValue = predicate(rxn);
      changed = firstTime || (nextValue != value);
      value = nextValue;
    });

    final canInvokeEffect =
        (firstTime && fireImmediately == true) || (!firstTime && changed);
    if (canInvokeEffect) {
      effectAction([value]);
    }
    if (firstTime) {
      firstTime = false;
    }
  }

  Timer timer;
  var isScheduled = false;

  rxn = Reaction(context, () {
    if (firstTime || runSync) {
      reactionRunner();
    } else if (!isScheduled) {
      isScheduled = true;

      if (timer != null) {
        timer.cancel();
        timer = null;
      }

      timer = scheduler(() {
        isScheduled = false;
        if (!rxn.isDisposed) {
          reactionRunner();
        } else {
          timer.cancel();
        }
      });
    }
  }, name: rxnName, onError: onError);

  // ignore: cascade_invocations
  rxn.schedule();

  return ReactionDisposer(rxn);
}

ReactionDisposer createWhenReaction(ReactiveContext context,
    bool Function(Reaction) predicate, void Function() effect,
    {String name, void Function(Object, Reaction) onError}) {
  final rxnName = name ?? context.nameFor('When');
  final effectAction = action(effect, name: '$rxnName-effect');

  return createAutorun(context, (reaction) {
    if (predicate(reaction)) {
      reaction.dispose();
      effectAction();
    }
  }, name: rxnName, onError: onError);
}

Future<void> createAsyncWhenReaction(
    ReactiveContext context, bool Function(Reaction) predicate,
    {String name}) {
  final completer = Completer<void>();
  createWhenReaction(context, predicate, completer.complete, name: name,
      onError: (error, reaction) {
    reaction.dispose();
    completer.completeError(error);
  });

  return completer.future;
}
