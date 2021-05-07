const path = require("path");
require("dotenv").config({
  path: path.resolve(__dirname, "../.env"),
});
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

// Deploy XBNv2
const XBNv2 = artifacts.require("XBNV2");

module.exports = async function(deployer, network, accounts) {
  const address = "0x946f099E6ce2c6206C98a8f4B8a8cbd09a1a4145";

  await upgradeProxy(address, XBNv2, { deployer });
};
// XBN
// 0x30b1eD7F9650e8411Eb5B95BC2da6EEDEfcA4b74
// ProxyAdmin
// 0x3f2651AE501798F11e24c3354A4af3E7b66EF253
// TransparentUpgradeableProxy
// 0x946f099E6ce2c6206C98a8f4B8a8cbd09a1a4145
