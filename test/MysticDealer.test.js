const {contract, web3} = require('@openzeppelin/test-environment');
const {expectRevert, BN} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const MysticDealer = contract.fromArtifact('MysticDealer');

let token, otherToken, mysticDealer, owner, anotherAccount, foundationAddress;

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
            new BN((0.05 * (10 ** 18)).toString()), // 0.05 E
            new BN((0.5 * (10 ** 18)).toString()) // 0.5 E
        );
    });

    describe('balance', function () {
        it('should return the balance of the token pool', async function () {
            await token.transfer(mysticDealer.address, 123);
            expect(await token.balanceOf(mysticDealer.address)).to.be.bignumber.equal('123');
        });
    });
    //
    // describe('transfer', function () {
    //   it('should let the owner transfer funds out', async function () {
    //     await token.transfer(tokenPool.address, 1000);
    //
    //     expect(await tokenPool.balance.call()).to.be.bignumber.equal('1000');
    //     expect(await token.balanceOf.call(anotherAccount)).to.be.bignumber.equal('0');
    //
    //     await tokenPool.transfer(anotherAccount, 1000);
    //
    //     expect(await tokenPool.balance.call()).to.be.bignumber.equal('0');
    //     expect(await token.balanceOf.call(anotherAccount)).to.be.bignumber.equal('1000');
    //   });
    //
    //   it('should NOT let other users transfer funds out', async function () {
    //     await token.transfer(tokenPool.address, 1000);
    //     await expectRevert(
    //       tokenPool.transfer(anotherAccount, 1000, { from: anotherAccount }),
    //       'Ownable: caller is not the owner'
    //     );
    //   });
    // });
});
