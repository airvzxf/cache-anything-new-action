const core = require("@actions/core");

console.log(`Hello World!`);

console.log(`*: ${core.getInput('*')}`)
console.log(`identifier: ${core.getInput('identifier')}`)
console.log(`inputs.identifier: ${core.getInput('inputs.identifier')}`)
console.log(`ENV_IDENTIFIER: ${core.getInput('ENV_IDENTIFIER')}`)
console.log(`env_identifier: ${core.getInput('env_identifier')}`)
console.log(`*: ${core.getInput('*')}`)
console.log(`[]: ${core.getInput('')}`)

const nameToGreet = core.getInput('inputs.identifier');
console.log(`Hello ${nameToGreet}!`);
