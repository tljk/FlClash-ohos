import { HvigorPlugin, HvigorNode } from '@ohos/hvigor';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';

const execFileAsync = promisify(execFile);

const buildkitDir = path.resolve(__dirname, '..');
const projectRoot = path.resolve(__dirname, '..', '..', '..', '..');

export function setupPlugin(): HvigorPlugin {
  return {
    pluginId: 'SetupPlugin',
    apply(node: HvigorNode) {
      node.registerTask({
        name: 'setup',
        run: async () => {
          const isWindows = process.platform === 'win32';
          const launcher = path.join(
            buildkitDir,
            isWindows ? 'run_build_tool.cmd' : 'run_build_tool.sh',
          );
          const archArgs = ['--arch', 'arm64'];

          const { stdout, stderr } = await execFileAsync(
            isWindows ? 'cmd' : launcher,
            isWindows ? ['/c', launcher, 'ohos', ...archArgs] : ['ohos', ...archArgs],
            {
              cwd: projectRoot,
              env: {
                ...process.env,
                APP_ENV: process.env.APP_ENV ?? 'pre',
              },
            },
          );
          if (stdout) console.log(stdout);
          if (stderr) console.error(stderr);
        },
        postDependencies: ['default@ConfigureCmake'],
      });
    },
  };
}