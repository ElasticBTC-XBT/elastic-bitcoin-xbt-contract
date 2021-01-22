const {contract, web3} = require('@openzeppelin/test-environment');
const {expectRevert} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');
const moment = require('moment');
const {getETHBalance, formatReadableValue} = require('../util/helpers');

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const HappyDealer = contract.fromArtifact('HappyDealer');

let token, otherToken, happyDealer, owner, anotherAccount, foundationWallet, buyer, anotherBuyer, anotherAccount3,
  anotherAccount2;

describe('HappyDealer', function () {
  beforeEach('setup contracts', async function () {
    const accounts = await chain.getUserAccounts();
    owner = web3.utils.toChecksumAddress(accounts[0]);
    buyer = web3.utils.toChecksumAddress(accounts[4]);
    anotherBuyer = web3.utils.toChecksumAddress(accounts[6]);
    anotherAccount = web3.utils.toChecksumAddress(accounts[5]);
    anotherAccount2 = web3.utils.toChecksumAddress(accounts[7]);
    anotherAccount3 = web3.utils.toChecksumAddress(accounts[3]);
    foundationWallet = web3.eth.accounts.create();

    token = await MockERC20.new(4000);
    otherToken = await MockERC20.new(2000);

    happyDealer = await HappyDealer.new(
      token.address, // token instance
      foundationWallet.address, // foundation address
      60, // 1 minute
      100, // 100 tokens
      formatReadableValue(0.05), // 0.05 E
      formatReadableValue(0.5) // 0.5 E
    );
    await token.transfer(happyDealer.address, 200);
  });

  describe('happy dealer major flows', async function () {
    it('should: return the sale rules', async function () {
      const saleRule = await happyDealer.getSaleRule();
      const {
        '0': minBidAmount, '1': maxBidAmount, '2': exchangeRate
      } = saleRule;
      expect(exchangeRate).to.be.bignumber.equal('100');
      expect(minBidAmount).to.be.bignumber.equal(formatReadableValue(0.05));
      expect(maxBidAmount).to.be.bignumber.equal(formatReadableValue(0.5));
    });

    it('should: return the balance of the mystic dealer', async function () {
      await token.transfer(happyDealer.address, 2000);
      expect(await token.balanceOf(happyDealer.address)).to.be.bignumber.equal('2200'); // 2000 at beforeEach and 200 at runtime testing
      expect(await otherToken.balanceOf(happyDealer.address)).to.be.bignumber.equal('0');
      const tokenBalance = await happyDealer.getSaleSupply();
      expect(tokenBalance).to.be.bignumber.equal('2200');
    });

    it('should: buyer transfers some ETHs and get XBTs back', async function () {
      await web3.eth.sendTransaction({
        from: buyer,
        to: happyDealer.address,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      expect(await getETHBalance(happyDealer.address)).to.be.bignumber.equal(formatReadableValue(0.5));
      const tokenBalance = await token.balanceOf(buyer);

      expect(
        tokenBalance.toString() === '100' ||
                tokenBalance.toString() === '50'
      ).to.be.true;
    });

    it('should: buyer execute contracts and get XBTs back', async function () {
      await happyDealer.exchangeToken({
        from: buyer,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      expect(await getETHBalance(happyDealer.address)).to.be.bignumber.equal(formatReadableValue(0.5));
      const tokenBalance = await token.balanceOf(buyer);

      expect(
        tokenBalance.toString() === '100' ||
                tokenBalance.toString() === '50'
      ).to.be.true;
    });

    it('should: let the owner transfer the funds out', async function () {
      await web3.eth.sendTransaction({
        from: buyer,
        to: happyDealer.address,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      await happyDealer.withdrawFund();

      expect(await getETHBalance(happyDealer.address)).to.be.bignumber.equal('0');
      expect(await getETHBalance(foundationWallet.address)).to.be.bignumber.equal(formatReadableValue(0.5));
    });

    it('should: participated time was recorded', async function () {
      await web3.eth.sendTransaction({
        from: buyer,
        to: happyDealer.address,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      const orderMeta = await happyDealer.getOrderMetaOf(buyer);

      const [participantWaitTime] = orderMeta;

      const now = moment();
      const participateDate = moment(Number(participantWaitTime) * 1000);
      expect(participateDate.diff(now, 'minute')).to.be.equal(0);
    });
  });

  describe('happy dealer handles major sale rules', function () {
    it('should: reject the bid is greater max bid amount', async function () {
      // send the second time should be rejected
      await expectRevert(
        web3.eth.sendTransaction({
          from: buyer,
          to: happyDealer.address,
          value: formatReadableValue(0.6),
          gas: 10e6
        }),
        'Error: must be less than max bid amount'
      );
    });

    it('should: reject the bid is less than min bid amount', async function () {
      // send the second time should be rejected
      await expectRevert(
        web3.eth.sendTransaction({
          from: buyer,
          to: happyDealer.address,
          value: formatReadableValue(0.01),
          gas: 10e6
        }),
        'Error: must be greater than min bid amount'
      );
    });

    it('should: reject if participant wait time is not reached', async function () {
      // send the first time
      await web3.eth.sendTransaction({
        from: buyer,
        to: happyDealer.address,
        value: formatReadableValue(0.1),
        gas: 10e6
      });

      // send the second time should be rejected
      await expectRevert(
        web3.eth.sendTransaction({
          from: buyer,
          to: happyDealer.address,
          value: formatReadableValue(0.5),
          gas: 10e6
        }),
        'Error: participant wait time is not reached'
      );
    });

    it('should: reject if the contract fund is exceed', async function () {
      await web3.eth.sendTransaction({
        from: owner,
        to: happyDealer.address,
        value: formatReadableValue(0.25),
        gas: 10e6
      });

      await web3.eth.sendTransaction({
        from: buyer,
        to: happyDealer.address,
        value: formatReadableValue(0.25),
        gas: 10e6
      });

      await web3.eth.sendTransaction({
        from: anotherBuyer,
        to: happyDealer.address,
        value: formatReadableValue(0.3),
        gas: 10e6
      });

      // send the second time should be rejected
      await expectRevert(
        Promise.all([
          web3.eth.sendTransaction({
            from: anotherAccount2,
            to: happyDealer.address,
            value: formatReadableValue(0.5),
            gas: 10e6
          }),
          web3.eth.sendTransaction({
            from: anotherAccount,
            to: happyDealer.address,
            value: formatReadableValue(0.5),
            gas: 10e6
          }),
          web3.eth.sendTransaction({
            from: anotherAccount3,
            to: happyDealer.address,
            value: formatReadableValue(0.5),
            gas: 10e6
          })
        ]),
        'Error: contract fund is exceeded'
      );
    });
  });
});
