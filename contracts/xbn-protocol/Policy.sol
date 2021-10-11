pragma solidity >=0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import "../lib/SafeMathInt.sol";
import "../lib/UInt256Lib.sol";
import "../lib/UniV2Library.sol";
import "./XBN.sol";


/**
 * @title XTH Monetary Supply Policy
 * @dev This is an implementation of the XTH Ideal Money protocol.
 *      XTH operates symmetrically on expansion and contraction. It will both split and
 *      combine coins to maintain a stable unit price.
 *
 *      This component regulates the token supply of the XTH ERC20 token in response to
 *      market oracles.
 */
contract XBNPolicy is OwnableUpgradeSafe {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using UInt256Lib for uint256;

    struct Transaction {
        bool enabled;
        address destination;
        bytes data;
    }

    event TransactionFailed(address indexed destination, uint index, bytes data);

    // Stable ordering is not guaranteed.
    Transaction[] public transactions;

    event LogRebase(
        uint256 indexed epoch,
        uint256 exchangeRate,
    // uint256 cpi,
        int256 requestedSupplyAdjustment,
        uint256 timestampSec
    );

    XBN public XBNs;


    // If the current exchange rate is within this fractional distance from the target, no supply
    // update is performed. Fixed point number--same format as the rate.
    // (ie) abs(rate - targetRate) / targetRate < deviationThreshold, then no supply change.
    // DECIMALS Fixed point number.
    uint256 public deviationThreshold;

    // The rebase lag parameter, used to dampen the applied supply adjustment by 1 / rebaseLag
    // Check setRebaseLag comments for more details.
    // Natural number, no decimal places.
    uint256 public rebaseLag;

    // More than this much time must pass between rebase operations.
    uint256 public minRebaseTimeIntervalSec;

    // Block timestamp of last rebase operation
    uint256 public lastRebaseTimestampSec;

    // The rebase window begins this many seconds into the minRebaseTimeInterval period.
    // For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
    uint256 public rebaseWindowOffsetSec;

    // The length of the time window where a rebase operation is allowed to execute, in seconds.
    uint256 public rebaseWindowLengthSec;

    // The number of rebase cycles since inception
    uint256 public epoch;

    uint256 private constant DECIMALS = 18;

    // Due to the expression in computeSupplyDelta(), MAX_RATE * MAX_SUPPLY must fit into an int256.
    // Both are 18 decimals fixed point numbers.
    uint256 private constant MAX_RATE = 10 ** 8 * 10 ** DECIMALS;
    // MAX_SUPPLY = MAX_INT256 / MAX_RATE
    uint256 private constant MAX_SUPPLY = ~(uint256(1) << 255) / MAX_RATE;


    uint256 private constant PRICE_PRECISION = 10 ** 2;


    IUniswapV2Pair public _pairXBNBNB;


    function setPairXBNBNB(address factory, address token0, address token1)
    external
    onlyOwner
    {
        _pairXBNBNB = IUniswapV2Pair(UniswapV2Library.pairFor(factory, token0, token1));

    }
    // function setToken0Token1(address token0, address token1)
    //     external
    //     onlyOwner
    // {
    // 	(address token0, address token1) = UniswapV2Library.sortTokens( token0, token1);

    // }


    function getPriceXBN_BNB() internal returns (uint256) {
        require(address(_pairXBNBNB) != address(0), "error: address(_pairXBNBNB) == address(0)");

        (uint256 reserves0, uint256 reserves1,) = _pairXBNBNB.getReserves();

        // reserves1 = ETH (18 decimals)
        // reserves0 = XTH (18 decimals)
        return reserves0.mul(PRICE_PRECISION).div(reserves1);
    }


    // /**
    //  * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
    //  *
    //  * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
    //  *      Where DeviationFromTargetRate is (exchangeRate - targetRate) / targetRate
    //  *      and targetRate is WBTC/USDC
    //  */
    // function rebase() external {


    //     require(msg.sender == tx.origin, "error: msg.sender == tx.origin");
    //     // solhint-disable-line avoid-tx-origin


    //     require(inRebaseWindow(), "Not inRebaseWindow");

    //     // This comparison also ensures there is no reentrancy.
    //     require(lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < now, "reentrancy error");

    //     // Snap the rebase time to the start of this window.
    //     lastRebaseTimestampSec = now.sub(
    //         now.mod(minRebaseTimeIntervalSec)).add(rebaseWindowOffsetSec);

    //     epoch = epoch.add(1);


    //     uint256 targetRate = 1 * PRICE_PRECISION;
    //     // 1 XTH = 1 ETH ==> 1.mul(10 ** PRICE_PRECISION);

    //     uint256 exchangeRate = getPriceXBN_BNB();

    //     if (exchangeRate > MAX_RATE) {
    //         exchangeRate = MAX_RATE;
    //     }

    //     int256 supplyDelta = computeSupplyDelta(exchangeRate, targetRate);


    //     // Apply the Dampening factor.
    //     supplyDelta = supplyDelta.div(rebaseLag.toInt256Safe());

    //     if (supplyDelta > 0 && XBNs.totalSupply().add(uint256(supplyDelta)) > MAX_SUPPLY) {
    //         supplyDelta = (MAX_SUPPLY.sub(XBNs.totalSupply())).toInt256Safe();
    //     }

    //     uint256 supplyAfterRebase = XBNs.rebase(epoch, supplyDelta);
    //     assert(supplyAfterRebase <= MAX_SUPPLY);
    //     emit LogRebase(epoch, exchangeRate, supplyDelta, now);


    //     for (uint i = 0; i < transactions.length; i++) {
    //         Transaction storage t = transactions[i];
    //         if (t.enabled) {
    //             bool result =
    //             externalCall(t.destination, t.data);
    //             if (!result) {
    //                 emit TransactionFailed(t.destination, i, t.data);
    //                 revert("Transaction Failed");
    //             }
    //         }
    //     }
    // }

    /**
     * @notice Adds a transaction that gets called for a downstream receiver of rebases
     * @param destination Address of contract destination
     * @param data Transaction data payload
     */
    function addTransaction(address destination, bytes calldata data)
    external
    onlyOwner
    {
        transactions.push(Transaction({
        enabled : true,
        destination : destination,
        data : data
        }));
    }

    /**
     * @param index Index of transaction to remove.
     *              Transaction ordering may have changed since adding.
     */
    function removeTransaction(uint index)
    external
    onlyOwner
    {
        require(index < transactions.length, "index out of bounds");

        if (index < transactions.length - 1) {
            transactions[index] = transactions[transactions.length - 1];
        }

        // transactions.length--;
        transactions.pop();
    }

    /**
     * @param index Index of transaction. Transaction ordering may have changed since adding.
     * @param enabled True for enabled, false for disabled.
     */
    function setTransactionEnabled(uint index, bool enabled)
    external
    onlyOwner
    {
        require(index < transactions.length, "index must be in range of stored tx list");
        transactions[index].enabled = enabled;
    }
    /**
     * @return Number of transactions, both enabled and disabled, in transactions list.
     */
    function transactionsSize()
    external
    view
    returns (uint256)
    {
        return transactions.length;
    }

    /**
     * @dev wrapper to call the encoded transactions on downstream consumers.
     * @param destination Address of destination contract.
     * @param data The encoded data payload.
     * @return True on success
     */
    function externalCall(address destination, bytes memory data)
    internal
    returns (bool)
    {
        bool result;
        assembly {// solhint-disable-line no-inline-assembly
        // "Allocate" memory for output
        // (0x40 is where "free memory" pointer is stored by convention)
            let outputAddress := mload(0x40)

        // First 32 bytes are the padded length of data, so exclude that
            let dataAddress := add(data, 32)

            result := call(
            // 34710 is the value that solidity is currently emitting
            // It includes callGas (700) + callVeryLow (3, to pay for SUB)
            // + callValueTransferGas (9000) + callNewAccountGas
            // (25000, in case the destination address does not exist and needs creating)

            // https://solidity.readthedocs.io/en/v0.6.12/yul.html#yul
            sub(gas(), 34710),
            destination,
            0, // transfer value in wei
            dataAddress,
            mload(data), // Size of the input, in bytes. Stored in position 0 of the array.
            outputAddress,
            0  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }



    /**
     * @notice Sets the deviation threshold fraction. If the exchange rate given by the market
     *         oracle is within this fractional distance from the targetRate, then no supply
     *         modifications are made. DECIMALS fixed point number.
     * @param deviationThreshold_ The new exchange rate threshold fraction.
     */
    function setDeviationThreshold(uint256 deviationThreshold_)
    external
    onlyOwner
    {
        deviationThreshold = deviationThreshold_;
    }

    /**
     * @notice Sets the rebase lag parameter.
               It is used to dampen the applied supply adjustment by 1 / rebaseLag
               If the rebase lag R, equals 1, the smallest value for R, then the full supply
               correction is applied on each rebase cycle.
               If it is greater than 1, then a correction of 1/R of is applied on each rebase.
     * @param rebaseLag_ The new rebase lag parameter.
     */
    function setRebaseLag(uint256 rebaseLag_)
    external
    onlyOwner
    {
        require(rebaseLag_ > 0);
        rebaseLag = rebaseLag_;
    }

    /**
     * @notice Sets the parameters which control the timing and frequency of
     *         rebase operations.
     *         a) the minimum time period that must elapse between rebase cycles.
     *         b) the rebase window offset parameter.
     *         c) the rebase window length parameter.
     * @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
     *        operations, in seconds.
     * @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
              the rebase interval, where the rebase window begins.
     * @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
     */
    function setRebaseTimingParameters(
        uint256 minRebaseTimeIntervalSec_,
        uint256 rebaseWindowOffsetSec_,
        uint256 rebaseWindowLengthSec_)
    external
    onlyOwner
    {
        require(minRebaseTimeIntervalSec_ > 0);
        require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_);

        minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
        rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
        rebaseWindowLengthSec = rebaseWindowLengthSec_;
    }

    /**
     * @dev ZOS upgradable contract initialization method.
     *      It is called at the time of contract creation to invoke parent class initializers and
     *      initialize the contract's state variables.
     */
    function initialize(XBN XBNs)
    public
    initializer
    {

        OwnableUpgradeSafe.__Ownable_init();

        // deviationThreshold = 0.05e8 = 5e6
        deviationThreshold = 5 * 10 ** (DECIMALS - 2);

        rebaseLag = 8 * 3 * 100;
        // 8 hours * 3 * 100 days
        minRebaseTimeIntervalSec = 24 * 60 * 60;
        // 24 hours;
        rebaseWindowOffsetSec = 0;
        //
        rebaseWindowLengthSec = 8 * 60 * 60;
        // 8 * 60 * 60 minutes;
        lastRebaseTimestampSec = 0;
        epoch = 0;

        XBNs = XBNs;

    }

    /**
     * @return If the latest block timestamp is within the rebase time window it, returns true.
     *         Otherwise, returns false.
     */
    function inRebaseWindow() public view returns (bool) {
        return (
        now.mod(minRebaseTimeIntervalSec) >= rebaseWindowOffsetSec &&
        now.mod(minRebaseTimeIntervalSec) < (rebaseWindowOffsetSec.add(rebaseWindowLengthSec))
        );
    }

    /**
     * @return Computes the total supply adjustment in response to the exchange rate
     *         and the targetRate.
     */
    function computeSupplyDelta(uint256 rate, uint256 targetRate)
    private
    view
    returns (int256)
    {
        if (withinDeviationThreshold(rate, targetRate)) {
            return 0;
        }


        int256 targetRateSigned = targetRate.toInt256Safe();

        int256 supply = XBNs.totalSupply().toInt256Safe();


        return supply.mul(rate.toInt256Safe().sub(targetRateSigned).div(targetRateSigned));
    }

    /**
     * @param rate The current exchange rate, an 18 decimal fixed point number.
     * @param targetRate The target exchange rate, an 18 decimal fixed point number.
     * @return If the rate is within the deviation threshold from the target rate, returns true.
     *         Otherwise, returns false.
     */
    function withinDeviationThreshold(uint256 rate, uint256 targetRate)
    private
    view
    returns (bool)
    {
        uint256 absoluteDeviationThreshold = targetRate.mul(deviationThreshold)
        .div(10 ** DECIMALS);

        return (rate >= targetRate && rate.sub(targetRate) < absoluteDeviationThreshold)
        || (rate < targetRate && targetRate.sub(rate) < absoluteDeviationThreshold);
    }
}
