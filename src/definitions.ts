export interface AudioSessionPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
