import type {
  IPlatformBridge,
  ServiceSurfaceDescriptor,
} from './PlatformBridge';

/**
 * iPadOS implementation backed by the native shell's `window.ferdiumNative`
 * shim (injected by `ipados/.../platform-bridge.js`). All calls are forwarded to
 * Swift via `WKScriptMessageHandler`.
 */
export class WebKitPlatformBridge implements IPlatformBridge {
  readonly platform = 'ipados' as const;

  private get native() {
    const { ferdiumNative } = window;
    if (!ferdiumNative) {
      throw new Error('WebKitPlatformBridge used outside the iPadOS shell');
    }
    return ferdiumNative;
  }

  async localSet(key: string, value: unknown): Promise<void> {
    await this.native.request('local.set', { key, value });
  }

  async localGet<T = unknown>(key: string): Promise<T | undefined> {
    const result = await this.native.request('local.get', { key });
    return result.value as T | undefined;
  }

  createService(descriptor: ServiceSurfaceDescriptor): void {
    this.native.send('service.create', { ...descriptor });
  }

  activateService(serviceId: string): void {
    this.native.send('service.activate', { serviceId });
  }

  removeService(serviceId: string): void {
    this.native.send('service.remove', { serviceId });
  }

  on(
    event: string,
    handler: (payload: Record<string, unknown>) => void,
  ): () => void {
    return this.native.on(event, handler);
  }
}
