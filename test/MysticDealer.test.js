const {contract, web3} = require('@openzeppelin/test-environment');
const {expectRevert, expectEvent} = require('@openzeppelin/test-helpers');
const {expect} = require('chai');
const moment = require('moment');
const {getETHBalance, formatReadableValue} = require('../util/helpers');

const _require = require('app-root-path').require;
const BlockchainCaller = _require('/util/blockchain_caller');
const chain = new BlockchainCaller(web3);

const MockERC20 = contract.fromArtifact('MockERC20');
const MysticDealer = contract.fromArtifact('MysticDealer');

let token, otherToken, mysticDealer, owner, anotherAccount, foundationWallet, buyer, anotherBuyer, anotherAccount3,
  anotherAccount2;

describe('MysticDealer', function () {
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

    mysticDealer = await MysticDealer.new(
      token.address, // token instance
      foundationWallet.address, // foundation address
      60, // 1 minute
      100, // 100 tokens
      formatReadableValue(0.05), // 0.05 E
      formatReadableValue(0.5) // 0.5 E
    );
    await token.transfer(mysticDealer.address, 200);
  });

  describe('mystic dealer major flows', async function () {
    it('should: return the exchange rate', async function () {
      const exchangeRate = await mysticDealer.getSaleRate();
      expect(exchangeRate).to.be.bignumber.equal('100');
    });

    it('should: return the balance of the mystic dealer', async function () {
      await token.transfer(mysticDealer.address, 2000);
      expect(await token.balanceOf(mysticDealer.address)).to.be.bignumber.equal('2200'); // 2000 at beforeEach and 200 at runtime testing
      expect(await otherToken.balanceOf(mysticDealer.address)).to.be.bignumber.equal('0');
      const tokenBalance = await mysticDealer.getSaleSupply();
      expect(tokenBalance).to.be.bignumber.equal('2200');
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
        tokenBalance.toString() === '100' ||
                tokenBalance.toString() === '50'
      ).to.be.true;
    });

    it('should: buyer execute contracts and get XBTs back', async function () {
      await mysticDealer.exchangeToken({
        from: buyer,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal(formatReadableValue(0.5));
      const tokenBalance = await token.balanceOf(buyer);

      expect(
        tokenBalance.toString() === '100' ||
                tokenBalance.toString() === '50'
      ).to.be.true;
    });

    it('should: let the owner transfer the funds out', async function () {
      await web3.eth.sendTransaction({
        from: buyer,
        to: mysticDealer.address,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      await mysticDealer.withdrawFund();

      expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal('0');
      expect(await getETHBalance(foundationWallet.address)).to.be.bignumber.equal(formatReadableValue(0.5));
    });

    it('should: lucky number is calculated and participated time was recorded', async function () {
      await web3.eth.sendTransaction({
        from: buyer,
        to: mysticDealer.address,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      const orderMeta = await mysticDealer.getOrderMetaOf(buyer);

      const [luckyNumber, participantWaitTime] = orderMeta;

      expect(!!luckyNumber).to.be.true; // expect the lucky number is calculated

      const now = moment();
      const participateDate = moment(Number(participantWaitTime) * 1000);
      expect(participateDate.diff(now, 'minute')).to.be.equal(0);
    });

    it('should: order is recorded with proper information', async function () {
      await web3.eth.sendTransaction({
        from: buyer,
        to: mysticDealer.address,
        value: formatReadableValue(0.1),
        gas: 10e6
      });

      await web3.eth.sendTransaction({
        from: anotherBuyer,
        to: mysticDealer.address,
        value: formatReadableValue(0.1),
        gas: 10e6
      });

      const orderBook = await mysticDealer.getOrderBook();

      expect(orderBook.length).to.be.equal(2);

      const [price, buyerAddress, bonusWon, timeStamp, purchasedTokenAmount, totalETHValue1] = orderBook[0];
      const [price2, buyerAddress2, bonusWon2, timeStamp2, purchasedTokenAmount2, totalETHValue2] = orderBook[1];

      // now for expect
      expect(Number(price)).to.be.equal(100);
      expect(Number(price2)).to.be.equal(100);

      expect(buyer).to.be.equal(buyerAddress);
      expect(anotherBuyer).to.be.equal(buyerAddress2);

      expect(!!timeStamp && !!bonusWon && !!purchasedTokenAmount).to.be.true;
      expect(!!timeStamp2 && !!bonusWon2 && !!purchasedTokenAmount2).to.be.true;

      expect(totalETHValue1).to.be.bignumber.equal(formatReadableValue(0.1));
      expect(totalETHValue2).to.be.bignumber.equal(formatReadableValue(0.1));
    });

    it('should: event is emitted properly', async function () {
      const receipt = await mysticDealer.exchangeToken({
        from: buyer,
        value: formatReadableValue(0.5),
        gas: 10e6
      });

      try {
        expectEvent(
          receipt,
          'OnSuccessfulSale', [
            '100',
            buyer,
            '0',
            parseInt((new Date().getTime() / 1000).toString()).toString(),
            '50',
            formatReadableValue(0.5)
          ]
        );
      } catch (e) {
        expectEvent(
          receipt,
          'OnSuccessfulSale', [
            '100',
            buyer,
            '50',
            parseInt((new Date().getTime() / 1000).toString()).toString(),
            '100',
            formatReadableValue(0.5)
          ]
        );
      }

      expect(await getETHBalance(mysticDealer.address)).to.be.bignumber.equal(formatReadableValue(0.5));
      const tokenBalance = await token.balanceOf(buyer);

      expect(
        tokenBalance.toString() === '100' ||
                tokenBalance.toString() === '50'
      ).to.be.true;
    });
  });

  describe('mystic dealer handles major sale rules', function () {
    it('should: reject the bid is greater max bid amount', async function () {
      // send the second time should be rejected
      await expectRevert(
        web3.eth.sendTransaction({
          from: buyer,
          to: mysticDealer.address,
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
          to: mysticDealer.address,
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
        to: mysticDealer.address,
        value: formatReadableValue(0.1),
        gas: 10e6
      });

      // send the second time should be rejected
      await expectRevert(
        web3.eth.sendTransaction({
          from: buyer,
          to: mysticDealer.address,
          value: formatReadableValue(0.5),
          gas: 10e6
        }),
        'Error: participant wait time is not reached'
      );
    });

    it('should: reject if the contract fund is exceed', async function () {
      await web3.eth.sendTransaction({
        from: owner,
        to: mysticDealer.address,
        value: formatReadableValue(0.25),
        gas: 10e6
      });

      await web3.eth.sendTransaction({
        from: buyer,
        to: mysticDealer.address,
        value: formatReadableValue(0.25),
        gas: 10e6
      });

      await web3.eth.sendTransaction({
        from: anotherBuyer,
        to: mysticDealer.address,
        value: formatReadableValue(0.3),
        gas: 10e6
      });

      // send the second time should be rejected
      await expectRevert(
        Promise.all([
          web3.eth.sendTransaction({
            from: anotherAccount2,
            to: mysticDealer.address,
            value: formatReadableValue(0.5),
            gas: 10e6
          }),
          web3.eth.sendTransaction({
            from: anotherAccount,
            to: mysticDealer.address,
            value: formatReadableValue(0.5),
            gas: 10e6
          }),
          web3.eth.sendTransaction({
            from: anotherAccount3,
            to: mysticDealer.address,
            value: formatReadableValue(0.5),
            gas: 10e6
          })
        ]),
        'Error: contract fund is exceeded'
      );
    });
  });
});
