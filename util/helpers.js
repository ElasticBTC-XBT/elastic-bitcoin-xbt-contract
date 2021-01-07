const {BN, balance} = require('@openzeppelin/test-helpers');

const formatReadableValue = readableValue =>
  new BN(
    (Number(readableValue) * (10 ** 18)).toString()
  ).toString();

const getETHBalance = address => new Promise(async (resolve, reject) => {
  try {
    const currentBalancePromise = await balance.tracker(address);
    const currentBalance = await currentBalancePromise.get();
    return resolve(currentBalance);
  } catch (err) {
    return reject(err);
  }
});

module.exports.formatReadableValue = formatReadableValue;
module.exports.getETHBalance = getETHBalance;
