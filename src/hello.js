const core = require("@actions/core");

console.log(`Hello World!`);

const nameToGreet = core.getInput('identifier');
console.log(`Hello ${nameToGreet}!`);
