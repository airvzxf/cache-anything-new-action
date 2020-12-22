const tool_cache = require('@actions/tool-cache');
const core = require('@actions/core');

async function run(): Promise<void> {
    console.log(`core.isDebug(): ${core.isDebug()}`)

    const allNodeVersions = tool_cache.findAllVersions('node');
    console.log(`Versions of node available: ${allNodeVersions}`);

    const nodeDirectory = tool_cache.find('node', '12.x', 'x64');
    core.addPath(nodeDirectory);
    console.log(`nodeDirectory: ${nodeDirectory}`)
    console.log(`core.getInput -> target-install.sh: ${core.getInput('target-install.sh')}`)
    console.log(`core.getInput -> myShellName:       ${core.getInput('myShellName')}`)
    console.log(`core.getInput -> myShellName1.0.0:  ${core.getInput('myShellName1.0.0')}`)
    console.log(`core.getInput -> myShellName-1.0.0: ${core.getInput('myShellName-1.0.0')}`)
    console.log(`core.getInput -> 1.0.0:             ${core.getInput('1.0.0')}`)
    console.log(`core.getInput -> node:       ${core.getInput('node')}`)
    console.log(`core.getInput -> identifier: ${core.getInput('identifier')}`)
    console.log(`core.getInput -> version:    ${core.getInput('version')}`)
    console.log(`core.getInput -> cache:      ${core.getInput('cache')}`)
    console.log(`core.getInput -> script:     ${core.getInput('script')}`)
    console.log(`core.getInput -> snapshot:   ${core.getInput('snapshot')}`)
    console.log(`core.getInput -> exclude:    ${core.getInput('exclude')}`)
    console.log(`core.getState -> #01: ${core.getState('CACHE_KEY')}`)
    console.log(`core.getState -> #02: ${core.getState('CACHE_RESULT')}`)

    try {
        const cachedPath = await tool_cache.cacheDir(nodeDirectory, 'node', '12.20.0');
        core.addPath(cachedPath);
        console.log(`cachedPath: ${cachedPath}`)
    } catch (e) {
        console.error("Error in: await tool_cache.cacheDir(nodeDirectory..)")
    }

    try {
        const cachedFile = await tool_cache.cacheFile('/home/runner/work/testing-actions-github/testing-actions-github/.github/workflows/install.sh', 'target-install.sh', 'myShellName', '1.0.0');
        core.addPath(cachedFile);
        console.log(`cachedFile: ${cachedFile}`)
    } catch (e) {
        console.error("Error in: await tool_cache.cacheFile('/home/...)")
    }

    const nodeDirectory_2 = tool_cache.find('node', '12.x', 'x64');
    core.addPath(nodeDirectory_2);

    const cachedFileFind = tool_cache.find('myShellName', '1.x');
    core.addPath(cachedFileFind);

    console.log(`core.getInput -> target-install.sh: ${core.getInput('target-install.sh')}`)
    console.log(`core.getInput -> myShellName:       ${core.getInput('myShellName')}`)
    console.log(`core.getInput -> myShellName1.0.0:  ${core.getInput('myShellName1.0.0')}`)
    console.log(`core.getInput -> myShellName-1.0.0: ${core.getInput('myShellName-1.0.0')}`)
    console.log(`core.getInput -> 1.0.0:             ${core.getInput('1.0.0')}`)
    console.log(`core.getInput -> node:       ${core.getInput('node')}`)
    console.log(`core.getInput -> identifier: ${core.getInput('identifier')}`)
    console.log(`core.getInput -> version:    ${core.getInput('version')}`)
    console.log(`core.getInput -> cache:      ${core.getInput('cache')}`)
    console.log(`core.getInput -> script:     ${core.getInput('script')}`)
    console.log(`core.getInput -> snapshot:   ${core.getInput('snapshot')}`)
    console.log(`core.getInput -> exclude:    ${core.getInput('exclude')}`)
    console.log(`core.getState -> #01: ${core.getState('CACHE_KEY')}`)
    console.log(`core.getState -> #02: ${core.getState('CACHE_RESULT')}`)
}

run().then(_ => console.log("Run -> Then()"));

export default run;

