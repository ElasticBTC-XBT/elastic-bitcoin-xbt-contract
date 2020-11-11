module.exports = {
  networks: {
    development: {
      protocol: 'http',
      host: 'localhost',
      port: 8545,
      gas: 5000000,
      gasPrice: 5e9,
      networkId: '*',
    },
    ropsten: {
      provider: () => new HDWalletProvider("[]", "https://ropsten.infura.io/v3/[]" ),
      
      networkId: 3,       // Ropsten's id
    }
  },
};
