/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */
require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const privateKeys = [process.env.PRIVATE_KEY]; // private keys
const xbtPrivateKeys = [process.env.XBT_PRIVATE_KEY]; // xbt genesis private keys
const web3 = require("web3");

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    mainnet: {
      provider: function() {
        return new HDWalletProvider(
          privateKeys,
          `https://mainnet.infura.io/v3/${process.env.INFURA_ID}`
        );
      },
      gas: 2000000,
      gasPrice: web3.utils.toWei("50", "gwei"),
      network_id: 1,
      skipDryRun: true,
      networkCheckTimeout: 100000,
    },
    local: {
      provider: function() {
        return new HDWalletProvider(privateKeys, "http://127.0.0.1:8545");
      },
      network_id: 5777, // Any network (default: none)
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(
          privateKeys,
          `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`
        );
      },
      gas: 5000000,
      gasPrice: 24000000000,
      network_id: 4,
      skipDryRun: true,
    },
    bsc_testnet: {
      provider: () =>
        new HDWalletProvider(
          privateKeys,
          "https://data-seed-prebsc-1-s2.binance.org:8545"
        ),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      // gas: 5000000,
      gasPrice: 10e9,
      skipDryRun: true,
      // networkCheckTimeout: 90000,
      // Resolve time out error
      // https://github.com/trufflesuite/truffle/issues/3356#issuecomment-721352724
    },
    bsc: {
      provider: () =>
        new HDWalletProvider(privateKeys, "https://bsc-dataseed1.binance.org"),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      gas: 10000000,
    },
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    ganache: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 7545, // Standard Ethereum port (default: none)
      network_id: 5777, // Any network (default: none)
    },
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    // ropsten: {
    // provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/YOUR-PROJECT-ID`),
    // network_id: 3,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
    // timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    // skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    // },
    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 100000,
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.8", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: { // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: false,
          runs: 200
        }
        // evmVersion: 'constantinople'
      }
    },
  },
  plugins: ["truffle-plugin-verify", "solidity-coverage"],
  api_keys: {
    bscscan: process.env.ETHERSCAN_KEY,
  },
};
