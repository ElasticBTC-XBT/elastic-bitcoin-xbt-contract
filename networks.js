require("dotenv").config();
const HDWalletProvider = require("@truffle/hdwallet-provider");

const privateKeys = [process.env.PRIVATE_KEY];

module.exports = {
  networks: {
    ganache: {
      url: "http://127.0.0.1:8545",
      chainId: 5777,
    },
    hardhat_local: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 250000000000,
    },
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_ID}`,
      },
      gas: "auto",
      gasPrice: "auto",
      chainId: 1,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 4,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`,
      accounts: [process.env.PRIVATE_KEY],
      gas: "auto",
      gasPrice: "auto",
      chainId: 1,
    },
    // bsc_testnet: {
    //   url: "https://data-seed-prebsc-1-s1.binance.org:8545",
    //   accounts: [process.env.PRIVATE_KEY],
    //   gas: "auto",
    //   gasPrice: "auto",
    //   chainId: 97,
    //   timeoutBlocks: 200,
    // },
    bsc_testnet: {
      provider: () =>
        new HDWalletProvider(
          privateKeys,
          "https://data-seed-prebsc-1-s2.binance.org:8545"
        ),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      gas: 5000000,
      gasPrice: 5000000000,
      skipDryRun: true,
      networkCheckTimeout: 90000,
      // Resolve time out error
      // https://github.com/trufflesuite/truffle/issues/3356#issuecomment-721352724
    },
    bsc: {
      provider: () =>
        new HDWalletProvider(
          privateKeys,
          "https://bsc-dataseed1.binance.org"
        ),
      
      gas: 5000000,
      gasPrice: 5000000000,
      chainId: 56,
      network_id: 56,
    },
  },
};
