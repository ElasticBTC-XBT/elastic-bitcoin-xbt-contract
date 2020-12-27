module.exports = {
  networks: {
    ganache: {
      url: 'http://127.0.0.1:7545',
      networkId: 5777
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      networkId: 4,
    },
  },
};
