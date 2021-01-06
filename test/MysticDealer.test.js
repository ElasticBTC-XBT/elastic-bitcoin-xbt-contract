const {contract, web3} = require('@openzeppelin/test-environment');
const {BN, balance} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const MysticDealer = contract.fromArtifact('MysticDealer');

let token, otherToken, mysticDealer, owner, anotherAccount, foundationWallet, buyer;

const formatReadableValue = (readableValue) =>
    new BN(
        (Number(readableValue) * (10 ** 18)).toString()
    ).toString();

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
        buyer = web3.utils.toChecksumAddress(accounts[4]);
        anotherAccount = web3.utils.toChecksumAddress(accounts[5]);
        foundationWallet = web3.eth.accounts.create();

        token = await MockERC20.new(4000);
        otherToken = await MockERC20.new(2000);

        mysticDealer = await MysticDealer.new(
            token.address, // token instance
            foundationWallet.address, // foundation address
            60, // 1 minute
            100, // 100 tokens
            formatReadableValue(0.05), // 0.05 E
            formatReadableValue(0.5) // 0.5 E
        );
        await token.transfer(mysticDealer.address, 2000);
    });

    describe('balance of mystic dealer', async function () {
        it('should return the balance of the mystic dealer', async function () {
            await token.transfer(mysticDealer.address, 2000);
            expect(await token.balanceOf(mysticDealer.address)).to.be.bignumber.equal('4000'); // 2000 at beforeEach and 2000 at runtime testing
            expect(await otherToken.balanceOf(mysticDealer.address)).to.be.bignumber.equal('0');
        });

        it('should: buyer transfers some ETHs and get XBTs back', async function () {
            await web3.eth.sendTransaction({
                from: buyer,
                to: mysticDealer.address,
                value: formatReadableValue(0.5),
                gas: 10e6
            });

            expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal(formatReadableValue(0.5));
            const tokenBalance = await token.balanceOf(buyer);

            expect(
                tokenBalance.toString() === '100'  ||
                tokenBalance.toString() === '50'
            ).to.be.true;
        })

        it('should let the owner transfer the funds out', async function () {
            await web3.eth.sendTransaction({
                from: buyer,
                to: mysticDealer.address,
                value: formatReadableValue(0.5),
                gas: 10e6
            });

            await mysticDealer.withdrawFund();

            expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal('0');
            expect(await getETHBalance(foundationWallet.address)).to.be.bignumber.equal(formatReadableValue(0.5));
        })
    });
});
