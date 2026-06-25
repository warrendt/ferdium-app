import { isWebKitHost } from '../environment';
import { ElectronPlatformBridge } from './electronBridge';
import type { IPlatformBridge } from './PlatformBridge';
import { WebKitPlatformBridge } from './webkitBridge';

export type {
  IPlatformBridge,
  ServiceSurfaceDescriptor,
  NotificationPayload,
} from './PlatformBridge';
export { ElectronPlatformBridge } from './electronBridge';
export { WebKitPlatformBridge } from './webkitBridge';

let instance: IPlatformBridge | undefined;

/**
 * Returns the platform bridge for the current host, constructing it lazily.
 *
 * On the native iPadOS shell (`window.ferdiumNative` present) this is the
 * WebKit bridge; everywhere else it is the Electron bridge.
 */
export function getPlatformBridge(): IPlatformBridge {
  if (!instance) {
    instance = isWebKitHost
      ? new WebKitPlatformBridge()
      : new ElectronPlatformBridge();
  }
  return instance;
}
