declare global {
  interface Window {
    ferdium: any;
    // Injected by the iPadOS native shell (see ipados/.../platform-bridge.js).
    // Absent on Electron, where the platform bridge talks to `electron` instead.
    ferdiumNative?: {
      platform: 'ipados';
      send: (command: string, payload?: Record<string, unknown>) => void;
      request: (
        command: string,
        payload?: Record<string, unknown>,
      ) => Promise<Record<string, unknown>>;
      on: (
        event: string,
        handler: (payload: Record<string, unknown>) => void,
      ) => () => void;
    };
  }

  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace NodeJS {
    interface ProcessEnv {
      GITHUB_AUTH_TOKEN: string;
      NODE_ENV: 'development' | 'production';
      FERDIUM_APPDATA_DIR?: string;
      PORTABLE_EXECUTABLE_FILE?: string;
      PORTABLE_EXECUTABLE_DIR?: string;
      ELECTRON_IS_DEV?: string;
      APPDATA?: string;
    }
  }
}

/**
 * Workaround to make TS recognize this file as a module.
 * https://fettblog.eu/typescript-augmenting-global-lib-dom/
 */
export type {};
