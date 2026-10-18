(function () {
  const viewerId = 'gesture-avatar-model';
  const listeners = new WeakSet();
  let pendingCommand = null;

  function report(message) {
    if (window.AvatarAnimationBridge) {
      window.AvatarAnimationBridge.postMessage(message);
    }
  }

  function applyCommand(command) {
    const viewer = document.getElementById(viewerId);
    if (!viewer || !viewer.model) {
      pendingCommand = command;
      return;
    }
    if (!viewer.availableAnimations.includes(command.animationName)) {
      const message = `Missing animation: ${command.animationName}`;
      console.error(message);
      report(`error:${message}`);
      pendingCommand = null;
      return;
    }

    viewer.animationName = command.animationName;
    if (command.playing) {
      viewer.play();
    } else {
      viewer.pause();
    }
    pendingCommand = null;
  }

  window.dispatchAvatarAnimationCommand = function (commandJson) {
    try {
      const command =
        typeof commandJson === 'string' ? JSON.parse(commandJson) : commandJson;
      if (!command || typeof command.animationName !== 'string') {
        throw new TypeError('Animation command is invalid.');
      }
      applyCommand(command);
    } catch (error) {
      console.error('Could not control the avatar animation:', error);
      report(`error:${error.message}`);
    }
  };

  window.addEventListener('avatarAnimationCommand', function (event) {
    window.dispatchAvatarAnimationCommand(event.detail);
  });

  function attachViewer() {
    const viewer = document.getElementById(viewerId);
    if (!viewer || listeners.has(viewer)) return;
    listeners.add(viewer);
    viewer.addEventListener('load', function () {
      if (pendingCommand) applyCommand(pendingCommand);
      report('ready');
    });
  }

  new MutationObserver(attachViewer).observe(document.documentElement, {
    childList: true,
    subtree: true
  });
  attachViewer();
})();
