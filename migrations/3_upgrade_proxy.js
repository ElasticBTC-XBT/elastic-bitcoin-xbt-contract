const path = require('path');
require('dotenv').config({
  path: path.resolve(__dirname, '../.env')
});
const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

// Upgrade XBN
const XBN = artifacts.require('XBN');

module.exports = async function (deployer, network, accounts) {
  const address = '0x0501479339Be0E4A54f4a04De77CB402e250EA18';

  await upgradeProxy(address, XBN, { deployer });
}

