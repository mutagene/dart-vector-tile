import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const [
  initModulePath,
  wasmPath,
  iterations = '5000',
  warmupIterations = '500',
] = process.argv.slice(2);

if (!initModulePath || !wasmPath) {
  console.error(
    'Usage: node tool/run_wasm_decode_benchmark.mjs '
      + '<compiled.mjs> <compiled.wasm> [iterations] [warmupIterations]',
  );
  process.exit(64);
}

const dartModule = await import(pathToFileURL(initModulePath));
const compiledApp = await dartModule.compile(await readFile(wasmPath));
const app = await compiledApp.instantiate({});

app.invokeMain(iterations, warmupIterations);
