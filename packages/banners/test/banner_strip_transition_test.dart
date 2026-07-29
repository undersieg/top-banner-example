import 'package:flutter_test/flutter_test.dart';
import 'package:banners/banners.dart';

const a = BannerSpec(message: 'a');
const b = BannerSpec(message: 'b');
const c = BannerSpec(message: 'c');

const animate = Duration(milliseconds: 220);

/// The collapse state machine, driven directly.
///
/// This is the point of having pulled it out of the widget: the shrink bug —
/// N -> N-1 snapping because the painted stack was adopted in the same frame the
/// strip started shrinking — is three lines here, and was invisible in 46 widget
/// tests that could only see pixel positions after a pump.
void main() {
  test('starts empty and idle', () {
    final strip = BannerStripTransition();
    expect(strip.painted, isEmpty);
    expect(strip.target, isEmpty);
    expect(strip.duration, Duration.zero);
    expect(strip.isSettled, isTrue);
    expect(strip.isIdle, isTrue);
  });

  test('growing adopts the new stack immediately, so it can be revealed', () {
    final strip = BannerStripTransition();
    expect(strip.retarget([a, b], duration: animate), isTrue);
    expect(strip.painted, [a, b]);
    expect(strip.target, [a, b]);
    expect(strip.duration, animate);
    // Nothing to hand over, but the animation still has to be stopped.
    expect(strip.isSettled, isTrue);
    expect(strip.isIdle, isFalse);
  });

  test('shrinking keeps painting the outgoing stack until it finishes', () {
    final strip = BannerStripTransition()
      ..retarget([a, b, c], duration: animate);
    strip.finish();

    strip.retarget([a], duration: animate);
    // The whole fix: three banners stay painted while the strip travels down to
    // one banner's worth of height. Adopting [a] here leaves nothing to animate.
    expect(strip.painted, [a, b, c]);
    expect(strip.target, [a]);
    expect(strip.isSettled, isFalse);

    expect(strip.finish(), isTrue);
    expect(strip.painted, [a]);
    expect(strip.isIdle, isTrue);
  });

  test('an unanimated shrink adopts the new stack at once', () {
    final strip = BannerStripTransition()..retarget([a, b], duration: animate);
    strip.finish();

    strip.retarget([a], duration: Duration.zero);
    expect(strip.painted, [a]);
    expect(strip.isIdle, isTrue);
  });

  test('retargeting the same stack changes nothing', () {
    final strip = BannerStripTransition()..retarget([a], duration: animate);
    final revision = strip.revision;

    expect(strip.accepts([a]), isFalse);
    expect(strip.retarget([a], duration: Duration.zero), isFalse);
    // Equal by value, not by identity: a fresh list of equal specs is not news.
    expect(
      strip.retarget([BannerSpec(message: 'a')], duration: animate),
      isFalse,
    );
    expect(strip.revision, revision);
    expect(strip.duration, animate, reason: 'the running transition is intact');
  });

  test('finishing stops animating, so a later resize does not slide', () {
    final strip = BannerStripTransition()..retarget([a], duration: animate);
    expect(strip.duration, animate);

    expect(strip.finish(), isTrue);
    expect(strip.duration, Duration.zero);
    // A metrics change — a rotation, a text scale change — rebuilds with a new
    // target height and no stack change. It should land, not animate.
    expect(strip.finish(), isFalse, reason: 'idempotent');
  });

  test('the revision distinguishes one transition from the next', () {
    // The host schedules `finish` a frame after the animation ends. If a new
    // navigation lands in between, that callback must not run: it would adopt
    // the newer target and stop the newer animation on its first frame.
    final strip = BannerStripTransition()..retarget([a, b], duration: animate);
    strip.finish();

    strip.retarget([a], duration: animate);
    final pending = strip.revision;

    strip.retarget([a, b, c], duration: animate);
    expect(
      strip.revision,
      isNot(pending),
      reason: 'the queued finish belongs to a transition that no longer exists',
    );
  });
}
