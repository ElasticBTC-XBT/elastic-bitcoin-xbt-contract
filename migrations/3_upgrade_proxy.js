const path = require('path');
require('dotenv').config({
  path: path.resolve(__dirname, '../.env')
});
const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

// Upgrade XBN
const XBN = artifacts.require('XBN');

module.exports = async function (deployer, network, accounts) {
  const address = '0x2a017B876c50104C7Db3Ca59BC9a7aaD67388513';

  await upgradeProxy(address, XBN, { deployer });
}

