#!/usr/bin/env node
const { execSync } = require('child_process');
const { runCoverage } = require('@openzeppelin/test-environment');

async function main () {
    await runCoverage(
        ['mocks', 'lib', 'xbt-protocol', 'xbt-staking'], // TODO: added test cases for protocol, staking and libs
        'npm run test',
        './node_modules/.bin/mocha --exit --timeout 10000 --recursive'.split(' '),
    );

    if (process.env.CI) {
        execSync('curl -s https://codecov.io/bash | bash -s -- -C "$CIRCLE_SHA1"', { stdio: 'inherit' });
    }
}

main().catch(e => {
    console.error(e);
    process.exit(1);
});
