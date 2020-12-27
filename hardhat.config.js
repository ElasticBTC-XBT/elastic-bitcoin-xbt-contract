require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');


/**
 * @type import('hardhat/config').HardhatUserConfig
 */

async function deployXBT() {
    // We get the contract to deploy
    const accounts = await web3.eth.getAccounts();
    const xbtContract = await ethers.getContractFactory("XBT");
    const xbt = await upgrades.deployProxy(xbtContract, [accounts[0]]);

    console.log("XBT deployed to:", xbt.address);
    console.log("XBT deployed by:", accounts[0]);
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
    defaultNetwork: "ganache",
    networks: require('./networks').networks,
};
