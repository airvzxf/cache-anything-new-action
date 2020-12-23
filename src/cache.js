const cache = require("@actions/cache");
const core = require("@actions/core");

core.info("core.info")

console.log(`core.isDebug(): ${core.isDebug()}`)

const key = 'hello-v1.0.1'
const restoreKeys = ['hello-']
const paths = [
    '/home/runner/work/testing-actions-github/testing-actions-github/.github/workflows/hello.txt'
]

function restoreCache(paths, key, restoreKeys) {
    return cache.restoreCache(paths, key, restoreKeys)
}

(async () => {
    try {
        const cacheId = await restoreCache(paths, key, '')
        console.log(`cacheID: ${cacheId}`)
    } catch (error) {
        console.error(`Error in restoreCache #1: ${error}`)
    }
})();

function saveCache(paths, key) {
    return cache.saveCache(paths, key)
}

(async () => {
    try {
        const cacheId = await saveCache(paths, key)
        console.log(`cacheID: ${cacheId}`)
    } catch (error) {
        console.error(`Error in saveCache #2: ${error}`)
    }
})();

(async () => {
    try {
        const cacheId = await restoreCache(paths, key, restoreKeys)
        console.log(`cacheID: ${cacheId}`)
    } catch (e) {
        console.error(`Error in restoreCache #3: ${e}`)
    }
})();
