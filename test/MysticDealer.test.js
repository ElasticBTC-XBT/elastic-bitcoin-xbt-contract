const {contract, web3} = require('@openzeppelin/test-environment');
const {expectRevert, send, BN, balance} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const MysticDealer = contract.fromArtifact('MysticDealer');

let token, otherToken, mysticDealer, owner, anotherAccount, foundationAddress;

const formatReadableETHValue = (readableValue) => new BN((Number(readableValue) * (10 ** 18)).toString());

const getETHBalance = (address) => new Promise(async (resolve, reject) => {
    try {
        const currentBalancePromise = await balance.tracker(address);
        const currentBalance = await currentBalancePromise.get();
        return resolve(currentBalance);
    } catch (err) {
        return reject(err);
    }
})

describe('MysticDealer', function () {
    beforeEach('setup contracts', async function () {
        const accounts = await chain.getUserAccounts();
        owner = web3.utils.toChecksumAddress(accounts[0]);
        anotherAccount = web3.utils.toChecksumAddress(accounts[8]);
        foundationAddress = web3.utils.toChecksumAddress(accounts[7]);

        token = await MockERC20.new(1000);
        otherToken = await MockERC20.new(2000);

        mysticDealer = await MysticDealer.new(
            token.address, // token instance
            foundationAddress, // foundation address
            60, // 5 secs
            70, // 1 ETH exchange for 70 tokens
            new BN(formatReadableETHValue(0.05)), // 0.05 E
            new BN(formatReadableETHValue(0.5)) // 0.5 E
        );
    });

    describe('balance of mystic dealer', function () {
        it('should return the balance of the mystic dealer', async function () {
            await token.transfer(mysticDealer.address, 123);
            expect(await token.balanceOf(mysticDealer.address)).to.be.bignumber.equal('123');
            expect(await otherToken.balanceOf(mysticDealer.address)).to.be.bignumber.equal('0');
        });

        it('should let the owner transfer the funds out', async function () {
            await token.transfer(mysticDealer.address, 500);
            await send.ether(owner, mysticDealer.address, formatReadableETHValue(0.05));
            expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal(formatReadableETHValue(10));

            await mysticDealer.withdrawFund();

            expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal('0');
            expect(await getETHBalance(foundationAddress)).to.be.bignumber.equal(formatReadableETHValue(10));
        })
    });
});
