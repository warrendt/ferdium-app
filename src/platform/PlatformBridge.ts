/**
 * Platform abstraction for the renderer.
 *
 * The renderer must run both under Electron (desktop) and under the native
 * iPadOS WKWebView shell (see `ipados/`). Anything that historically reached out
 * to `electron`/`@electron/remote`/`ipc-api` directly should instead go through
 * an `IPlatformBridge`, so the underlying transport can be swapped per platform.
 *
 * Two implementations exist:
 *  - `ElectronPlatformBridge`  — wraps `ipcRenderer` (desktop, default).
 *  - `WebKitPlatformBridge`    — wraps `window.ferdiumNative` (iPadOS).
 *
 * Use {@link getPlatformBridge} to obtain the correct one for the host.
 */

export interface ServiceSurfaceDescriptor {
  id: string;
  url: string;
  partition?: string;
  userAgent?: string;
}

export interface NotificationPayload {
  title: string;
  options: { body?: string; [key: string]: unknown };
  notificationId: string;
}

export interface IPlatformBridge {
  /** Stable identifier for the host platform. */
  readonly platform: 'electron' | 'ipados';

  /** Persist a value in the local-first store (replaces the AdonisJS server on iPad). */
  localSet(key: string, value: unknown): Promise<void>;

  /** Read a value from the local-first store. */
  localGet<T = unknown>(key: string): Promise<T | undefined>;

  /** Create (or warm) an isolated surface for a service. No-op on Electron. */
  createService(descriptor: ServiceSurfaceDescriptor): void;

  /** Bring a service surface to the foreground. No-op on Electron. */
  activateService(serviceId: string): void;

  /** Tear down a service surface. No-op on Electron. */
  removeService(serviceId: string): void;

  /**
   * Subscribe to a native event (e.g. `service-unread`, `deep-link`).
   * Returns an unsubscribe function.
   */
  on(
    event: string,
    handler: (payload: Record<string, unknown>) => void,
  ): () => void;
}
