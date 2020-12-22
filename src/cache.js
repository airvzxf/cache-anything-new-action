const tool_cache = require('@actions/tool-cache');
const core = require('@actions/core');

console.log(`core.isDebug(): ${core.isDebug()}`)

const allNodeVersions = tool_cache.findAllVersions('node');
console.log(`Versions of node available: ${allNodeVersions}`);

const nodeDirectory = tool_cache.find('node', '12.x', 'x64');
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

function cachedPathFunction() {
    return tool_cache.cacheDir(nodeDirectory, 'node', '12.20.0');
}

(async () => {
    try {
        const cachedPath = await cachedPathFunction();
        console.log(`cachedPath: ${cachedPath}`);
        core.addPath(cachedPath);

        const nodeDirectory = tool_cache.find('node', '12.x', 'x64');
        core.addPath(nodeDirectory);
        console.log(`nodeDirectory: ${nodeDirectory}`)

        const cachedFileFind = tool_cache.find('myShellName', '1.x');
        core.addPath(cachedFileFind);
        console.log(`cachedFileFind: ${cachedFileFind}`)
    } catch (e) {
        console.error(`Error in cachedPath: ${e}`)
    }
})();

function cachedFileFunction() {
    return tool_cache.cacheFile('/home/runner/work/testing-actions-github/testing-actions-github/.github/workflows/install.sh', 'target-install.sh', 'myShellName', '1.0.0');
}

(async () => {

    try {
        const cachedFile = await cachedFileFunction();
        console.log(`cachedFile: ${cachedFile}`)
        core.addPath(cachedFile);

        const nodeDirectory = tool_cache.find('node', '12.x', 'x64');
        core.addPath(nodeDirectory);
        console.log(`nodeDirectory: ${nodeDirectory}`)

        const cachedFileFind = tool_cache.find('myShellName', '1.x');
        core.addPath(cachedFileFind);
        console.log(`cachedFileFind: ${cachedFileFind}`)
    } catch (e) {
        console.error(`Error in cachedFile: ${e}`)
    }
})();
