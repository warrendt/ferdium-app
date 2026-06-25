/*
 * Ferdium iPadOS recipe bridge.
 *
 * Injected at document start into every service WKWebView. It is the WebKit
 * equivalent of the Electron preload `src/webview/recipe.ts` glue: it exposes the
 * `window.ferdium` API that recipes call, and re-implements the notification
 * monkey-patch from `src/webview/notifications.ts` so web/service-worker
 * notifications are routed to native `UNUserNotificationCenter`.
 *
 * `__SERVICE_ID__` is replaced by native code (BridgeScripts.recipeBridge).
 */
(() => {
  const SERVICE_ID = '__SERVICE_ID__';
  const onClickCallbacks = new Map();

  function post(type, payload) {
    if (
      window.webkit &&
      window.webkit.messageHandlers &&
      window.webkit.messageHandlers.ferdium
    ) {
      window.webkit.messageHandlers.ferdium.postMessage({
        serviceId: SERVICE_ID,
        type,
        payload,
      });
    }
  }

  // The API surface recipes expect on `window.ferdium`. Mirrors the methods
  // exposed via contextBridge in src/webview/recipe.ts.
  window.ferdium = window.ferdium || {};

  window.ferdium.setBadge = (direct, indirect) => {
    const toInt = value => {
      const parsed = Number.parseInt(value, 10);
      return Number.isNaN(parsed) ? 0 : parsed;
    };
    post('badge', { direct: toInt(direct), indirect: toInt(indirect) });
  };

  window.ferdium.setDialogTitle = title => {
    post('dialog-title', { title });
  };

  window.ferdium.displayNotification = (title, options = {}) => {
    const notificationId = `ntf-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    return new Promise(resolve => {
      onClickCallbacks.set(notificationId, resolve);
      post('notification', { title, options, notificationId });
    });
  };

  // Allow native code to resolve a notification's click (banner tapped).
  window.ferdiumRecipe = {
    __onNotificationClick(notificationId) {
      const resolve = onClickCallbacks.get(notificationId);
      if (resolve) {
        onClickCallbacks.delete(notificationId);
        resolve(true);
      }
    },
  };

  // Notification monkey-patch, ported from src/webview/notifications.ts.
  class WrapNotification {
    static permission = 'granted';

    constructor(title = '', options = {}) {
      this._onclick = null;
      window.ferdium.displayNotification(title, options).then(() => {
        if (this._onclick) {
          this._onclick();
        }
      });
    }

    static requestPermission(cb) {
      if (typeof cb === 'function') {
        cb(WrapNotification.permission);
      }
      return Promise.resolve(WrapNotification.permission);
    }

    close() {
      this._onclick = null;
    }

    set onclick(callback) {
      this._onclick = callback;
    }
  }

  const OriginalNotification = window.Notification;
  if (OriginalNotification) {
    Object.setPrototypeOf(WrapNotification.prototype, OriginalNotification.prototype);
  }
  window.Notification = WrapNotification;

  // Some sites use service workers for notifications; redirect those too.
  if (window.ServiceWorkerRegistration) {
    window.ServiceWorkerRegistration.prototype.showNotification = function showNotification(
      title = '',
      options = {},
    ) {
      // Only `body` matters in practice (see notifications.ts comment).
      // eslint-disable-next-line no-new
      new WrapNotification(title, { body: options.body });
    };
  }
})();
