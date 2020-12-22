const core = require("@actions/core");

console.log(`Hello World!`);

const nameToGreet = core.getInput('who-to-greet');
console.log(`Hello ${nameToGreet}!`);
