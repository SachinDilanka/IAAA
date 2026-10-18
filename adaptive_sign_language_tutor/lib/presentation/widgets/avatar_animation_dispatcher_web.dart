import 'dart:js_interop';

@JS('window.dispatchAvatarAnimationCommand')
external void _dispatchAvatarAnimationCommand(JSString commandJson);

void dispatchAvatarAnimation(String commandJson) {
  _dispatchAvatarAnimationCommand(commandJson.toJS);
}
