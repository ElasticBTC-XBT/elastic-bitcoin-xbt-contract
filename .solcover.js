module.exports = {
  norpc: true,
  testCommand: 'npm run test',
  compileCommand: 'npm run compile-contracts',
  copyPackages: ['openzeppelin-eth', 'openzeppelin-solidity'],
  skipFiles: ['lib','mocks', 'xbt-staking', 'xbt-protocol']
};
