import { ipcRenderer } from 'electron';
import type { IPlatformBridge } from './PlatformBridge';

/**
 * Desktop implementation backed by Electron.
 *
 * Service surfaces are managed by the React renderer itself (the
 * `react-electron-web-view` elements in `ServiceWebview.tsx`), so the
 * service-lifecycle methods are intentionally no-ops here — they exist only so
 * the renderer can share a single code path with the iPadOS shell. Local-first
 * values are kept in `localStorage`, which the embedded server already mirrors.
 */
export class ElectronPlatformBridge implements IPlatformBridge {
  readonly platform = 'electron' as const;

  async localSet(key: string, value: unknown): Promise<void> {
    window.localStorage.setItem(key, JSON.stringify(value));
  }

  async localGet<T = unknown>(key: string): Promise<T | undefined> {
    const raw = window.localStorage.getItem(key);
    if (raw == null) {
      return undefined;
    }
    return JSON.parse(raw) as T;
  }

  createService(): void {
    // Handled by the renderer's <ElectronWebView>; nothing to do natively.
  }

  activateService(): void {
    // Handled by the renderer's service switcher.
  }

  removeService(): void {
    // Handled by the renderer when the webview unmounts.
  }

  on(
    event: string,
    handler: (payload: Record<string, unknown>) => void,
  ): () => void {
    const listener = (
      _event: unknown,
      payload: Record<string, unknown>,
    ): void => handler(payload);
    ipcRenderer.on(event, listener);
    return () => {
      ipcRenderer.removeListener(event, listener);
    };
  }
}
