const {contract, web3} = require('@openzeppelin/test-environment');
const {expectRevert} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');
const moment = require("moment");
const {formatReadableValue} = require("./helpers");

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const AirdropLander = contract.fromArtifact('AirdropLander');

let token, otherToken, airdropLander, owner, buyer, anotherBuyer, anotherBuyer2, anotherBuyer3;

describe('AirdropLander', function () {
    beforeEach('setup contracts for airdrop lander test', async function () {
        const accounts = await chain.getUserAccounts();
        owner = web3.utils.toChecksumAddress(accounts[0]);
        buyer = web3.utils.toChecksumAddress(accounts[4]);
        anotherBuyer = web3.utils.toChecksumAddress(accounts[6]);
        anotherBuyer2 = web3.utils.toChecksumAddress(accounts[5]);
        anotherBuyer3 = web3.utils.toChecksumAddress(accounts[7]);

        token = await MockERC20.new(4000);
        otherToken = await MockERC20.new(2000);

        airdropLander = await AirdropLander.new(
            token.address, // token instance
            100, // claimable amount
            60, // next period wait time
            50, // min rate
            100, // max rate
        );
        await token.transfer(airdropLander.address, 200);
    });

    describe('airdrop lander major flows', async function () {
        it('should: return the balance of the airdrop', async function () {
            await token.transfer(airdropLander.address, 2000);
            expect(await token.balanceOf(airdropLander.address)).to.be.bignumber.equal('2200'); // 2000 at beforeEach and 200 at runtime testing
            expect(await otherToken.balanceOf(airdropLander.address)).to.be.bignumber.equal('0');
        });

        it('should: buyer claim some XBTs', async function () {
            await airdropLander.requestTokens({from: buyer});
            const tokenBalance = await token.balanceOf(buyer);
            expect(tokenBalance).to.be.bignumber.greaterThan('50');
            expect(tokenBalance).to.be.bignumber.lessThan('150');
        })

        it('should: participant wait time is recorded properly', async function () {
            await airdropLander.requestTokens({from: buyer});
            const participantWaitTime = await airdropLander.participantWaitTimeOf(buyer);
            const now = moment();
            const participateDate = moment(Number(participantWaitTime) * 1000);
            expect(participateDate.diff(now, 'minute')).to.be.equal(0);
        })
    });

    describe('airdrop lander handles major airdrop rules', function () {
        it('should: reject if participant wait time is not reached', async function () {
            // send the first time
            await airdropLander.requestTokens({from: buyer});

            // send the second time should be rejected
            await expectRevert(
                airdropLander.requestTokens({from: buyer}),
                'Error: participant wait time is not reached'
            )
        });

        it('should: reject if the contract fund is exceed', async function () {
            // send the second time should be rejected
            await expectRevert(
                Promise.all([
                    airdropLander.requestTokens({from: buyer}),
                    airdropLander.requestTokens({from: owner}),
                    airdropLander.requestTokens({from: anotherBuyer2}),
                    airdropLander.requestTokens({from: anotherBuyer}),
                    airdropLander.requestTokens({from: anotherBuyer3})
                ]),
                'Error: contract fund is exceeded'
            )
        });
    })
});
