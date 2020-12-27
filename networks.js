require('dotenv').config();

module.exports = {
  networks: {
    ganache: {
      url: 'http://127.0.0.1:7545',
      chainId: 5777
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      chainId: 4,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [process.env.PRIVATE_KEY],
      gas: 'auto',
      gasPrice: 'auto'
    }
  },
};
