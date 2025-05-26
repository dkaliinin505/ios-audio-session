import { WebPlugin } from '@capacitor/core';

import type { AudioSessionPlugin } from './definitions';

export class AudioSessionWeb extends WebPlugin implements AudioSessionPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
