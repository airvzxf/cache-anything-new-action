import * as core from "@actions/core";

console.log(`Hello World!`);
console.log(process.env)

const nameToGreet = core.getInput('inputs.identifier');
console.log(`Hello ${nameToGreet}!`);
