const core = require("@actions/core");

console.log(`Hello World!`);

console.log(`*: ${core.getInput('*')}`)
console.log(`identifier: ${core.getInput('identifier')}`)
console.log(`inputs.identifier: ${core.getInput('inputs.identifier')}`)

const nameToGreet = core.getInput('inputs.identifier');
console.log(`Hello ${nameToGreet}!`);
