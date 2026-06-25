/*
 * Ferdium iPadOS host bridge shim.
 *
 * Injected at document start into the host WKWebView (the React renderer). It
 * exposes `window.ferdiumNative`, the WebKit replacement for the Electron
 * `ipc-api` modules. The renderer's PlatformBridge (see
 * `src/platform/webkitBridge.ts`) talks to this object instead of `electron`.
 *
 * Renderer -> native:  window.ferdiumNative.send(command, payload)
 * Renderer -> native (request/response): window.ferdiumNative.request(command, payload) -> Promise
 * Native   -> renderer: native calls window.ferdiumNative.__receive({ event, payload })
 */
(() => {
  if (window.ferdiumNative) {
    return;
  }

  const listeners = new Map();
  const pending = new Map();
  let requestSeq = 0;

  function post(message) {
    if (
      window.webkit &&
      window.webkit.messageHandlers &&
      window.webkit.messageHandlers.ferdium
    ) {
      window.webkit.messageHandlers.ferdium.postMessage(message);
    }
  }

  window.ferdiumNative = {
    platform: 'ipados',

    // Fire-and-forget command to native.
    send(command, payload = {}) {
      post({ command, payload });
    },

    // Command with a native reply, resolved via `reply:<id>` events.
    request(command, payload = {}) {
      requestSeq += 1;
      const requestId = `req-${requestSeq}`;
      return new Promise(resolve => {
        pending.set(requestId, resolve);
        post({ command, payload, requestId });
      });
    },

    // Subscribe to a native event. Returns an unsubscribe function.
    on(event, handler) {
      if (!listeners.has(event)) {
        listeners.set(event, new Set());
      }
      listeners.get(event).add(handler);
      return () => listeners.get(event).delete(handler);
    },

    // Invoked by native code (see PlatformBridge.dispatchToRenderer).
    __receive(envelope) {
      if (!envelope || typeof envelope.event !== 'string') {
        return;
      }
      const { event, payload } = envelope;

      if (event.startsWith('reply:')) {
        const requestId = event.slice('reply:'.length);
        const resolve = pending.get(requestId);
        if (resolve) {
          pending.delete(requestId);
          resolve(payload);
        }
        return;
      }

      const handlers = listeners.get(event);
      if (handlers) {
        handlers.forEach(handler => {
          try {
            handler(payload);
          } catch (error) {
            // Never let one listener break the dispatch loop.
            // eslint-disable-next-line no-console
            console.error('ferdiumNative listener error', error);
          }
        });
      }
    },
  };
})();
