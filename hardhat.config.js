require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

async function deployXBT() {
    // We get the contract to deploy
    const xbtContract = await ethers.getContractFactory("XBT");
    const xbt = await xbtContract.deploy();

    console.log("XBT deployed to:", xbt.address);
}

task("deployXBT", "Deploy XBT Contract").setAction(async () => {
    await deployXBT();
});

async function deployAirdropLander(dTokenAddress, claimableAmount) {
    // We get the contract to deploy
    const airdropLanderContract = await ethers.getContractFactory("AirdropLander");
    const lander = await airdropLanderContract.deploy(dTokenAddress, claimableAmount);

    console.log("AirdropLander deployed to:", lander.address);
}

task("deployAirdropLander", "Deploy AirdropLander")
    .addParam("address", "The distribution token's address")
    .addParam("claimable", "Claimable amount")
    .setAction(async (taskArgs) => {
    await deployAirdropLander(taskArgs.address, taskArgs.claimable);
});

module.exports = {
    solidity: "0.6.8",
    defaultNetwork: "development",
    networks: require('./networks').networks,
};
