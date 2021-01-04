pragma solidity >=0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import "../lib/SafeMathInt.sol";
import "../lib/UInt256Lib.sol";
import "./XBT.sol";



library UniswapV2Library {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // // performs chained getAmountOut calculations on any number of pairs
    // function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
    //     require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
    //     amounts = new uint[](path.length);
    //     amounts[0] = amountIn;
    //     for (uint i; i < path.length - 1; i++) {
    //         (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
    //         amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
    //     }
    // }

    // // performs chained getAmountIn calculations on any number of pairs
    // function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
    //     require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
    //     amounts = new uint[](path.length);
    //     amounts[amounts.length - 1] = amountOut;
    //     for (uint i = path.length - 1; i > 0; i--) {
    //         (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
    //         amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
    //     }
    // }
}



/**
 * @title XBT Monetary Supply Policy
 * @dev This is an implementation of the XBT Ideal Money protocol.
 *      XBT operates symmetrically on expansion and contraction. It will both split and
 *      combine coins to maintain a stable unit price.
 *
 *      This component regulates the token supply of the XBT ERC20 token in response to
 *      market oracles.
 */
contract Policy is OwnableUpgradeSafe {
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

    XBT public XBTs;


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

    uint256 private constant DECIMALS = 8;

    // Due to the expression in computeSupplyDelta(), MAX_RATE * MAX_SUPPLY must fit into an int256.
    // Both are 18 decimals fixed point numbers.
    uint256 private constant MAX_RATE = 10**8 * 10**DECIMALS;
    // MAX_SUPPLY = MAX_INT256 / MAX_RATE
    uint256 private constant MAX_SUPPLY = ~(uint256(1) << 255) / MAX_RATE;



    uint256 private constant PRICE_PRECISION = 10**2;



    //IUniswapV2Pair private _pairXBTWBTC;
    IUniswapV2Pair public _pairXBTWBTC;


	function setPairXBTWBTC(address factory, address token0, address token1)
        external
        onlyOwner
    {
        // as deploy:  0x5f8886272c7b3b5fd5c520534a6152205c3ce651
		_pairXBTWBTC = IUniswapV2Pair(UniswapV2Library.pairFor(factory, token0, token1));

    }
    // function setToken0Token1(address token0, address token1)
    //     external
    //     onlyOwner
    // {
	// 	(address token0, address token1) = UniswapV2Library.sortTokens( token0, token1);

    // }


    function getPriceXBT_WBTC() internal returns (uint256) {


	    require(address(_pairXBTWBTC) != address(0), "error: address(_pairXBTWBTC) == address(0)" );


	    (uint256 reserves0, uint256 reserves1,) = _pairXBTWBTC.getReserves();
        console.log("reserves0 %s", reserves0);
        console.log("reserves1 %s", reserves1);

	    // reserves1 = XBT (8 decimals)
	    // reserves0 = WBTC (8 decimals)
        // {
        // pair(id:"0x5f8886272c7b3b5fd5c520534a6152205c3ce651") {
        //     id,
        //     token0 {
        //     id
        //     },
        //     token1 {
        //     id
        //     }
            
        // }
        // }

        // {
        // "data": {
        //     "pair": {
        //     "id": "0x5f8886272c7b3b5fd5c520534a6152205c3ce651",
        //     "token0": {
        //         "id": "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"
        //     },
        //     "token1": {
        //         "id": "0x64fb96d0395f6bf105f35233911e3df2c5bf4ce8"
        //     }
        //     }
        // }
        // }

        return reserves0.mul(PRICE_PRECISION).div(reserves1);
    }


    /**
     * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
     *
     * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
     *      Where DeviationFromTargetRate is (exchangeRate - targetRate) / targetRate
     *      and targetRate is WBTC/USDC
     */
    function rebase() external  {


         require(msg.sender == tx.origin, "error: msg.sender == tx.origin");  // solhint-disable-line avoid-tx-origin


        require(inRebaseWindow(), "Not inRebaseWindow");

        // This comparison also ensures there is no reentrancy.
        require(lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < now, "reentrancy error");

        // Snap the rebase time to the start of this window.
        lastRebaseTimestampSec = now.sub(
            now.mod(minRebaseTimeIntervalSec)).add(rebaseWindowOffsetSec);

        epoch = epoch.add(1);


        uint256 targetRate = 1 * PRICE_PRECISION; // 1 XBT = 1 WBTC ==> 1.mul(10 ** PRICE_PRECISION);

        uint256 exchangeRate = getPriceXBT_WBTC();

        console.log("exchangeRate %s",exchangeRate );

        if (exchangeRate > MAX_RATE) {
            exchangeRate = MAX_RATE;
        }

        int256 supplyDelta = computeSupplyDelta(exchangeRate, targetRate);


        // Apply the Dampening factor.
        supplyDelta = supplyDelta.div(rebaseLag.toInt256Safe());

        if (supplyDelta > 0 && XBTs.totalSupply().add(uint256(supplyDelta)) > MAX_SUPPLY) {
            supplyDelta = (MAX_SUPPLY.sub(XBTs.totalSupply())).toInt256Safe();
        }

        uint256 supplyAfterRebase = XBTs.rebase(epoch, supplyDelta);
        assert(supplyAfterRebase <= MAX_SUPPLY);
        emit LogRebase(epoch, exchangeRate, supplyDelta, now);


        for (uint i = 0; i < transactions.length; i++) {
            Transaction storage t = transactions[i];
            if (t.enabled) {
                bool result =
                    externalCall(t.destination, t.data);
                if (!result) {
                    emit TransactionFailed(t.destination, i, t.data);
                    revert("Transaction Failed");
                }
            }
        }
    }

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
            enabled: true,
            destination: destination,
            data: data
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
        assembly {  // solhint-disable-line no-inline-assembly
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
                sub(gas() , 34710),


                destination,
                0, // transfer value in wei
                dataAddress,
                mload(data),  // Size of the input, in bytes. Stored in position 0 of the array.
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
        require(minRebaseTimeIntervalSec_ > 0,"minRebaseTimeIntervalSec_ > 0");
        require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_,"rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_");

        minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
        rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
        rebaseWindowLengthSec = rebaseWindowLengthSec_;
    }

    /**
     * @dev ZOS upgradable contract initialization method.
     *      It is called at the time of contract creation to invoke parent class initializers and
     *      initialize the contract's state variables.
     */
    function initialize( XBT XBTs_)
        public
        initializer
    {

        OwnableUpgradeSafe.__Ownable_init();

        // deviationThreshold = 0.05e8 = 5e6
        deviationThreshold = 5 * 10 ** (DECIMALS-2);

        rebaseLag =  100; //  100 days
        minRebaseTimeIntervalSec = 24 * 60 * 60; // 24 hours;
        rebaseWindowOffsetSec = 0;  // no offset
        rebaseWindowLengthSec =  23 * 60 * 60 + 59 * 60;// 23 hours + 59 minutes
        lastRebaseTimestampSec = 0;
        epoch = 0;

        XBTs = XBTs_;
        _pairXBTWBTC = IUniswapV2Pair(UniswapV2Library.pairFor(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 0x64fB96d0395f6bf105F35233911e3dF2C5bf4Ce8, 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599));

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

        int256 supply =  XBTs.totalSupply().toInt256Safe();


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
