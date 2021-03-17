const {contract, web3} = require('@openzeppelin/test-environment');
const {expectRevert} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');
// const moment = require('moment');

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const QuestAirdrop = contract.fromArtifact('QuestAirdrop');

let token, otherToken, questAirdrop, owner, buyer, newOwner;//, anotherBuyer, anotherBuyer2, anotherBuyer3;

describe('QuestAirdrop', function () {
  beforeEach('setup contracts for airdrop lander test', async function () {
    const accounts = await chain.getUserAccounts();
    owner = web3.utils.toChecksumAddress(accounts[0]);
    buyer = web3.utils.toChecksumAddress(accounts[4]);
    newOwner = web3.utils.toChecksumAddress(accounts[6]);
    // anotherBuyer2 = web3.utils.toChecksumAddress(accounts[5]);
    // anotherBuyer3 = web3.utils.toChecksumAddress(accounts[7]);

    token = await MockERC20.new(4000);
    otherToken = await MockERC20.new(2000);

    questAirdrop = await QuestAirdrop.new(
      token.address, // token instance
      50, // min rate
      100, // max rate
    );
    await token.transfer(questAirdrop.address, 200);
  });

  describe('airdrop lander major flows', async function () {
    it('should: return the balance of the airdrop', async function () {
      await token.transfer(questAirdrop.address, 2000);
      expect(await token.balanceOf(questAirdrop.address)).to.be.bignumber.equal('2200'); // 2000 at beforeEach and 200 at runtime testing
      expect(await otherToken.balanceOf(questAirdrop.address)).to.be.bignumber.equal('0');
    });

    it('should: generate quest codes', async function () {
      await questAirdrop.generateQuestCode(1, 100, {from: owner});
      const questCodes = await questAirdrop.getQuestCodes();
      const questCodeMetaData = await questAirdrop.getCodeMetaData(questCodes[0]);

      const [rewardCode, status, claimableAmount, claimedBy, claimedAt, createdAt] = questCodeMetaData;

      expect(!!rewardCode).to.be.equal(true);
      expect(status).to.be.bignumber.equal('1');
      expect(claimableAmount).to.be.bignumber.equal('100');
      expect(!!claimedAt).to.be.equal(true);
      expect(!!createdAt).to.be.equal(true);
      expect(claimedBy).to.be.equal('0x0000000000000000000000000000000000000000');
    });

    it('should: user can claim reward properly, and then the code is destroyed', async function () {
      await questAirdrop.generateQuestCode(1, 100, {from: owner});
      const questCodes = await questAirdrop.getQuestCodes();

      await questAirdrop.claimRewardCode(questCodes[0], {from: buyer});

      const tokenBalance = await token.balanceOf(questAirdrop.address);
      expect(tokenBalance).to.be.bignumber.greaterThan('0');

      const questCodeMetaData = await questAirdrop.getCodeMetaData(questCodes[0]);

      const [rewardCode, status, claimableAmount, claimedBy, claimedAt, createdAt] = questCodeMetaData;

      expect(!!rewardCode).to.be.equal(true);
      expect(status).to.be.bignumber.equal('0');
      expect(claimableAmount).to.be.bignumber.equal('100');
      expect(claimedBy).to.be.equal(buyer);
      expect(!!claimedAt).to.be.equal(true);
      expect(!!createdAt).to.be.equal(true);

      await expectRevert(
        questAirdrop.claimRewardCode(questCodes[0], {from: buyer}),
        'Error: The code is invalid'
      );
    });

    it('should: emergency withdraw', async function () {
      questAirdrop.setOwner(newOwner, {from: owner});

      let tokenBalance = await token.balanceOf(newOwner);
      expect(tokenBalance).to.be.bignumber.equal('0');

      await expectRevert(
        questAirdrop.emergencyWithdraw({from: buyer}),
        'Error: Only owner can handle this operation ;)'
      );

      await expectRevert(
        questAirdrop.emergencyWithdraw({from: owner}),
        'Error: Only owner can handle this operation ;)'
      );

      await questAirdrop.emergencyWithdraw({from: newOwner});
      tokenBalance = await token.balanceOf(newOwner);
      expect(tokenBalance).to.be.bignumber.greaterThan('0');
    });
  });
  //
  // describe('airdrop lander handles major airdrop rules', function () {
  //   it('should: reject if participant wait time is not reached', async function () {
  //     // send the first time
  //     await airdropLander.requestTokens({from: buyer});
  //
  //     // send the second time should be rejected
  //     await expectRevert(
  //       airdropLander.requestTokens({from: buyer}),
  //       'Error: participant wait time is not reached'
  //     );
  //   });
  //
  //   it('should: reject if the contract fund is exceed', async function () {
  //     // send the second time should be rejected
  //     await expectRevert(
  //       Promise.all([
  //         airdropLander.requestTokens({from: buyer}),
  //         airdropLander.requestTokens({from: owner}),
  //         airdropLander.requestTokens({from: anotherBuyer2}),
  //         airdropLander.requestTokens({from: anotherBuyer}),
  //         airdropLander.requestTokens({from: anotherBuyer3})
  //       ]),
  //       'Error: contract fund is exceeded'
  //     );
  //   });
  // });
});
