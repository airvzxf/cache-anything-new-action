const tc = require('@actions/tool-cache');
const core = require('@actions/core');

const allNodeVersions = tc.findAllVersions('node');
console.log(`Versions of node available: ${allNodeVersions}`);

const nodeDirectory = tc.find('node', '12.x', 'x64');
core.addPath(nodeDirectory);
console.log(`nodeDirectory: ${nodeDirectory}`)
console.log(`core.getInput -> XxX: ${core.getInput('Linux-cache-wolf-primes-key-v1.1')}`)
console.log(`core.getInput -> key: ${core.getInput('key')}`)
console.log(`core.getState -> #01: ${core.getState('CACHE_KEY')}`)
console.log(`core.getState -> #02: ${core.getState('CACHE_RESULT')}`)
