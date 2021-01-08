require('dotenv').config();

module.exports = {
  networks: {
    ganache: {
      url: 'http://127.0.0.1:7545',
      chainId: 5777
    },
    hardhat_local: {
      url: 'http://127.0.0.1:8545'
    },
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_ID}`
      }
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 4
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [process.env.PRIVATE_KEY],
      gas: 'auto',
      gasPrice: 'auto',
      chainId: 1
    }
  }
};
