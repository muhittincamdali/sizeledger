// Records the README demos as terminal SVGs (light and dark) in docs/media/ by running the built
// command on the SampleShop fixtures from the repository root, as a reader would.
//
//   swift build -c release && node scripts/demo.mjs
//
// The output is what the command printed, colour included; nothing is typed by hand.
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { terminalSvg } from './terminal-svg.mjs';

const ROOT = fileURLToPath(new URL('../', import.meta.url));
const MEDIA = `${ROOT}docs/media/`;
const BINARY = `${ROOT}.build/release/sizeledger`;

const DEMOS = [
  {
    name: 'analyze',
    title: 'sizeledger · SampleShop 2.0 (.ipa)',
    comment: '# Fixtures/apps: a SwiftUI sample app, built for the iOS Simulator',
    args: ['analyze', 'Fixtures/apps/SampleShop-2.0.ipa', '--top', '5'],
  },
  {
    name: 'analyze-1.0',
    title: 'sizeledger · SampleShop 1.0 (.ipa)',
    comment: '# the previous version of the same app: one framework, four languages',
    args: ['analyze', 'Fixtures/apps/SampleShop-1.0.ipa', '--top', '5'],
  },
];

mkdirSync(MEDIA, { recursive: true });
for (const demo of DEMOS) {
  const output = execFileSync(BINARY, [...demo.args, '--color', 'always'], { cwd: ROOT, encoding: 'utf8' });
  const session = { title: demo.title, comment: demo.comment, command: `sizeledger ${demo.args.join(' ')}`, output };
  for (const theme of ['light', 'dark']) {
    writeFileSync(`${MEDIA}demo-${demo.name}-${theme}.svg`, terminalSvg(session, theme));
  }
  console.log(`docs/media/demo-${demo.name}-{light,dark}.svg`);
}
