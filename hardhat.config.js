require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("solidity-coverage");
require("@nomiclabs/hardhat-etherscan");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

async function deployXBT() {
  // We get the contract to deploy
  const accounts = await web3.eth.getAccounts();
  const xbtContract = await ethers.getContractFactory("XBN");
  const xbt = await upgrades.deployProxy(xbtContract, [accounts[0]]);

  console.log("XBT deployed to:", xbt.address);
  console.log("XBT deployed by:", accounts[0]);
}

task("deployXBT", "Deploy XBT Contract").setAction(async () => {
  await deployXBT();
});

// async function deployXBTRebaser() {
//     // We get the contract to deploy
//     const accounts = await web3.eth.getAccounts();
//     const xbtContract = await ethers.getContractFactory("XBT");
//     const xbt = await upgrades.deployProxy(xbtContract, [accounts[0]]);

//     console.log("XBT deployed to:", xbt.address);
//     console.log("XBT deployed by:", accounts[0]);
// }

// task("deployXBTRebaser", "Deploy XBT Rebaser").setAction(async () => {
//     await deployXBTRebaser();
// });

async function deployAirdropLander(
  dTokenAddress,
  claimableAmount,
  bonusPeriodSecs,
  minBonusRatio,
  maxBonusRatio
) {
  // We get the contract to deploy
  const airdropLanderContract = await ethers.getContractFactory(
    "AirdropLander"
  );

  const lander = await airdropLanderContract.deploy(
    dTokenAddress,
    claimableAmount,
    bonusPeriodSecs,
    minBonusRatio,
    maxBonusRatio
  );

  console.log("AirdropLander deployed to:", lander.address);
}

task("deployAirdropLander", "Deploy AirdropLander")
  .addParam("address", "The distribution token's address")
  .addParam("claimable", "Claimable amount")
  .addParam("bonusperiodsecs", "Duration time between 2 claims")
  .addParam("minbonusratio", "Min bonus ratio")
  .addParam("maxbonusratio", "Max bonuns ratio")
  .setAction(async (taskArgs) => {
    await deployAirdropLander(
      taskArgs.address,
      taskArgs.claimable,
      taskArgs.bonusperiodsecs,
      taskArgs.minbonusratio,
      taskArgs.maxbonusratio
    );
  });

module.exports = {
  solidity: "0.8.2",
  defaultNetwork: "ganache",
  networks: require("./networks").networks,
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  etherscan: {
    apiKey: "1CP1YJFMPHJD54Z88EYDHFRU6KN82Z4DRR",
  },
};
