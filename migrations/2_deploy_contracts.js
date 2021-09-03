const path = require('path');
require('dotenv').config({
  path: path.resolve(__dirname, '../.env')
});


// // Deploy
const Reseller = artifacts.require('Reseller');
module.exports = async function (deployer, network, accounts) {
  // 60 * 60 * 24 * 2
  await deployer.deploy(Reseller,
    '0x547cbe0f0c25085e7015aa6939b28402eb0ccdac',
    '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F', // router address
    '0x9d1ed5eC71F39d8d64BCb34EC039813426F94c10'
  );
};


// #PancakeSwap on BSC testnet:

// Factory: 0x6725F303b657a9451d8BA641348b6761A6CC7a17

// Router: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1


// Pancake Mainnet: 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F