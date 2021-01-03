const { GSNDevProvider } = require('@openzeppelin/gsn-provider');

module.exports = {
  accounts: {
    amount: 10, // Number of unlocked accounts
    ether: 100, // Initial balance of unlocked accounts (in ether)
  },

  contracts: {
    type: 'truffle', // Contract abstraction to use: 'truffle' for @truffle/contract or 'web3' for web3-eth-contract
    defaultGas: 10e6, // Maximum gas for contract calls (when unspecified)

    // Options available since v0.1.2
    defaultGasPrice: 20e10, // Gas price for contract calls (when unspecified)
    artifactsDir: 'build/contracts', // Directory where contract artifacts are stored
  },

  node: { // Options passed directly to Ganache client
    gasLimit: 10e6, // Maximum gas per block
    gasPrice: 20e10 // Sets the default gas price for transactions if not otherwise specified.
  },

  setupProvider: baseProvider => {
    const { accounts } = require('@openzeppelin/test-environment');

    return new GSNDevProvider(baseProvider, {
      txfee: 70,
      useGSN: false,
      ownerAddress: accounts[8],
      relayerAddress: accounts[9]
    });
  }
};
