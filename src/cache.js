const tc = require('@actions/tool-cache');
const core = require('@actions/core');

const allNodeVersions = tc.findAllVersions('node');
console.log(`Versions of node available: ${allNodeVersions}`);

const nodeDirectory = tc.find('node', '12.x', 'x64');
core.addPath(nodeDirectory);
console.log(`nodeDirectory: ${nodeDirectory}`)
console.log(`core.getInput -> identifier: ${core.getInput('identifier')}`)
console.log(`core.getInput -> version:    ${core.getInput('version')}`)
console.log(`core.getInput -> cache:      ${core.getInput('cache')}`)
console.log(`core.getInput -> script:     ${core.getInput('script')}`)
console.log(`core.getInput -> snapshot:   ${core.getInput('snapshot')}`)
console.log(`core.getInput -> exclude:    ${core.getInput('exclude')}`)
console.log(`core.getState -> #01: ${core.getState('CACHE_KEY')}`)
console.log(`core.getState -> #02: ${core.getState('CACHE_RESULT')}`)
