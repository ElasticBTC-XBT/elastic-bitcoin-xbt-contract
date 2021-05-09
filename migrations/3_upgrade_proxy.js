const path = require("path");
require("dotenv").config({
  path: path.resolve(__dirname, "../.env"),
});
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

// Deploy XBNv2
const XTNv2 = artifacts.require("XTNv2");

module.exports = async function(deployer, network, accounts) {
  const address = "0x76bF8D7E2186fF8C64D2b588f9e35d1d9D803906";

  await upgradeProxy(address, XTNv2, { deployer });
};