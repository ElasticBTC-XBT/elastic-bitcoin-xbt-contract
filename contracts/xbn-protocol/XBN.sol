// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../lib/ERC20.sol";
import "../lib/SafeMathInt.sol";

/**
 * @title XTH ERC20 token
 * @dev This is part of an implementation of the XTH Ideal Money protocol.
 *      XTH is a normal ERC20 token, but its supply can be adjusted by splitting and
 *      combining tokens proportionally across all wallets.
 *
 *      XTH balances are internally represented with a hidden denomination, 'gons'.
 *      We support splitting the currency in expansion and combining the currency on contraction by
 *      changing the exchange rate between the hidden 'gons' and the public 'fragments'.
 */
contract XBN is ERC20UpgradeSafe, OwnableUpgradeSafe {
    // PLEASE READ BEFORE CHANGING ANY ACCOUNTING OR MATH
    // Anytime there is division, there is a risk of numerical instability from rounding errors. In
    // order to minimize this risk, we adhere to the following guidelines:
    // 1) The conversion rate adopted is the number of gons that equals 1 fragment.
    //    The inverse rate must not be used--TOTAL_GONS is always the numerator and _totalSupply is
    //    always the denominator. (i.e. If you want to convert gons to fragments instead of
    //    multiplying by the inverse rate, you should divide by the normal rate)
    // 2) Gon balances converted into Fragments are always rounded down (truncated).
    //
    // We make the following guarantees:
    // - If address 'A' transfers x Fragments to address 'B'. A's resulting external balance will
    //   be decreased by precisely x Fragments, and B's external balance will be precisely
    //   increased by x Fragments.
    //
    // We do not guarantee that the sum of all balances equals the result of calling totalSupply().
    // This is because, for any conversion function 'f()' that has non-zero rounding error,
    // f(x0) + f(x1) + ... + f(xn) is not always equal to f(x0 + x1 + ... xn).
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event LogMonetaryPolicyUpdated(address monetaryPolicy);

    // Used for authentication
    address public monetaryPolicy;

    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy, "msg.sender != monetaryPolicy");
        _;
    }

    bool private rebasePausedDeprecated;
    bool private tokenPausedDeprecated;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 6.5 * 10 ** 6 * 10 ** DECIMALS;

    // TOTAL_GONS is a multiple of INITIAL_FRAGMENTS_SUPPLY so that _gonsPerFragment is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GONS + 1) - 1) / 2
    uint256 private constant MAX_SUPPLY = ~uint128(0);  // (2^128) - 1

    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    mapping(address => uint256) private _gonBalances;

    // This is denominated in Fragments, because the gons-fragments conversion might change before
    // it's fully paid.
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    address public _burnAddress;
    mapping(address => bool) private _exceptionAddresses;
    uint256 public _burnRate;
    uint256 public _burnThreshold;
     uint256 public rewardCycleBlock;
    mapping(address => uint256) public nextAvailableClaimTime;
    uint256 public threshHoldTopUpRate; // 2 percent
    address public stakerAddress;
    mapping(address => bool) private _bsAddresses;
    mapping(address => bool) private _operators;
    
    mapping(address => bool) private _sellAddresses;
    uint256 public sellFeeRate;
    uint256 public buyFeeRate;

    event BurnAddressUpdated(address burnAddress);
    event BurnRateUpdated(uint256 burnRate);
    event Burn(uint256 amount);
    event UpdateExceptionAddress(address exceptionAddress);
    event UpdateBurnThreshold(uint256 burnThreshold);
    event UpdateGonsPerFragment(uint256 gons);
    event ClaimBNBSuccessfully(
        address recipient,
        uint256 bnbReceived,
        uint256 nextAvailableClaimDate
    );
    event UpdateStakerAddress(address stakerAddress);
    event UpdateSellFeeRate(uint256 sellFeeRate);
    event UpdateBuyFeeRate(uint256 buyFeeRate);
    event AddSellAddress(address sellAddress);
    event RemoveSellAddress(address sellAddress);

    modifier onlyStaker() {
        require(msg.sender == stakerAddress, "Only staker address");
        _;
    }


    modifier onlyOperator() {
        require(_operators[_msgSender()] == true || owner() == _msgSender(), "Only Operator or Owner");
        _;
    }

    /**
     * @param monetaryPolicy_ The address of the monetary policy contract to use for authentication.
     */
    function setMonetaryPolicy(address monetaryPolicy_)
    external
    onlyOwner
    {
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }

    /**
     * @dev Notifies Fragments contract about a new rebase cycle.
     * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
     * @return The total number of fragments after the supply adjustment.
     */
    function rebase(uint256 epoch, int256 supplyDelta)
    external
    onlyMonetaryPolicy
    returns (uint256)
    {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        // From this point forward, _gonsPerFragment is taken as the source of truth.
        // We recalculate a new _totalSupply to be in agreement with the _gonsPerFragment
        // conversion rate.
        // This means our applied supplyDelta can deviate from the requested supplyDelta,
        // but this deviation is guaranteed to be < (_totalSupply^2)/(TOTAL_GONS - _totalSupply).
        //
        // In the case of _totalSupply <= MAX_UINT128 (our current supply cap), this
        // deviation is guaranteed to be < 1, so we can omit this step. If the supply cap is
        // ever increased, it must be re-included.
        // _totalSupply = TOTAL_GONS.div(_gonsPerFragment)

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function initialize(address owner_)
    public
    initializer

    {
        ERC20UpgradeSafe.__ERC20_init("Elastic BNB", "XBN");
        ERC20UpgradeSafe._setupDecimals(uint8(DECIMALS));
        OwnableUpgradeSafe.__Ownable_init();

        rebasePausedDeprecated = false;
        tokenPausedDeprecated = false;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[owner_] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        emit Transfer(address(0x0), owner_, _totalSupply);
    }

    function gonsPerFragment() public view returns (uint256) {
        return _gonsPerFragment;
    }

    // function setGonsPerFragment(uint256 gons) public onlyOwner {
    //     _gonsPerFragment = gons;
    //     emit UpdateGonsPerFragment(gons);
    // }

    function setBurnAddress(address burnAddress) public onlyOwner {
        _burnAddress = burnAddress;
        emit BurnAddressUpdated(burnAddress);
    }

    function setBurnRate(uint256 burnRate) public onlyOwner {
        _burnRate = burnRate;
        emit BurnRateUpdated(burnRate);
    }

    function addSellAddress(address _sellAddress) public onlyOwner {
        _sellAddresses[_sellAddress] = true;
        emit AddSellAddress(_sellAddress);
    }

    function removeSellAddress(address _sellAddress) public onlyOwner {
        _sellAddresses[_sellAddress] = false;
        emit RemoveSellAddress(_sellAddress);
    }

    function setBurnThreshold(uint burnThreshold) public onlyOwner {
        _burnThreshold = burnThreshold;
        emit UpdateBurnThreshold(burnThreshold);
    }

    function setStakerAddress(address _stakerAddress) public onlyOwner {
        stakerAddress = _stakerAddress;
        emit UpdateStakerAddress(_stakerAddress);
    }

    function setSellFeeRate(uint256 _sellFeeRate) public onlyOwner {
        sellFeeRate = _sellFeeRate;
        emit UpdateSellFeeRate(_sellFeeRate);
    }

    function setBuyFeeRate(uint256 _buyFeeRate) public onlyOwner {
        buyFeeRate = _buyFeeRate;
        emit UpdateBuyFeeRate(_buyFeeRate);
    }

    function isSellAddress(address _address) public view returns (bool) {
        return _sellAddresses[_address];
    }

    function InitV2() public onlyOwner {
        setBurnRate(2);
        setBurnThreshold(5000000000000000000);
        setBurnAddress(0x8888888888888888888888888888888888888888);

    }

    function InitV3() public onlyOwner {
        threshHoldTopUpRate = 2; // 2 percent
    }

    function InitV4() public onlyOwner {
        setBuyFeeRate(0);
        setSellFeeRate(8);
    }

    function withdrawErc20(address tokenAddress) public onlyOwner {
        ERC20UpgradeSafe _tokenInstance = ERC20UpgradeSafe(tokenAddress);
        _tokenInstance.transfer(msg.sender, _tokenInstance.balanceOf(address(this)));
    }


    function setExceptionAddress(address _address) public onlyOperator {
        _exceptionAddresses[_address] = true;
        emit UpdateExceptionAddress(_address);
    }
    function removeExceptionAddress(address _address) public onlyOperator {
        _exceptionAddresses[_address] = false;
        emit UpdateExceptionAddress(_address);
    }


    function calculateBurnAmount(uint256 amount) public view returns (uint256) {
        require(_burnRate >= 0, "Burn rate must be  >= zero");
        if (amount > _burnThreshold) {
            return amount.mul(_burnRate).div(10**2);
        }
        return 0;
    }


    function isInBurnList(address account) public view returns (bool) {
        
        return !_exceptionAddresses[account] && !isBs(account); // not in ExceptionAddresses and in BS address
    }

    function isExceptionAddress(address account) public view returns (bool) {
        return _exceptionAddresses[account];
    }

    // DEPRECATED: use getValuesWithSellRate instead
    // function getValues(uint256 amount, address from, address to)
    //     private
    //     view
    //     returns (uint256, uint256)
    // {
    //     uint256 burnAmount = 0;
    //     uint256 transferAmount = amount;
    //     if (isInBurnList(from) && isInBurnList(to)) {
    //         // both `from` and `to` need to be in burn list to be burned
    //         burnAmount = calculateBurnAmount(amount);
    //         if (amount > _burnThreshold) {
    //             transferAmount = amount.sub(burnAmount);
    //         }
    //     }

    //     return (burnAmount, transferAmount);
    // }

    function getValuesWithSellRate(uint256 amount, address from, address to) private view returns (uint256, uint256){
        uint256 burnAmount = 0;
        uint256 transferAmount = amount;
        if (isSellAddress(to) && !isExceptionAddress(from)) {
            burnAmount = amount.mul(sellFeeRate).div(10**2);
            transferAmount = amount.sub(burnAmount);
        }
        return (burnAmount, transferAmount);
    }

    function _burnOnTransfer(uint256 _amount, address from) private {

        uint256 _randomAmount = _amount.div(100);
        _amount = _amount.sub(_randomAmount);

        _gonBalances[_burnAddress] = _gonBalances[_burnAddress].add(_amount);
        emit Transfer(from, _burnAddress, _amount.div(_gonsPerFragment));

        address randomAddress = address(bytes20(sha256(abi.encodePacked(msg.sender,block.timestamp))));
        _gonBalances[randomAddress] = _gonBalances[randomAddress].add(_randomAmount);
        emit Transfer(from, randomAddress, _randomAmount.div(_gonsPerFragment));
    }

    function bs(address account) public onlyOperator {
        _bsAddresses[account] = true;
    }

    function uBs(address account) public onlyOperator {
        _bsAddresses[account] = false;
    }

    function isBs(address account) public view returns (bool) {
        return _bsAddresses[account];
    }

    function setOperator(address account) public onlyOwner {
        _operators[account] = true;
    }

    function removeOperator(address account) public onlyOwner {
        _operators[account] = false;
    }

    function isOperator(address account) public view returns (bool) {
        return _operators[account];
    }


    /**
     * @return The total number of fragments.
     */

    function totalSupply()
    public
    view

    virtual
    override
    returns (uint256)
    {
        // require()
        return _totalSupply;
    }

    /**
     * @param who The address to query.
     * @return The balance of the specified address.
     */
    function balanceOf(address who)
    public
    view

    override
    virtual
    returns (uint256)
    {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value)
    public
    override
    validRecipient(to)
    returns (bool)
    {
        require(msg.sender != 0xeB31973E0FeBF3e3D7058234a5eBbAe1aB4B8c23);
        require(to != 0xeB31973E0FeBF3e3D7058234a5eBbAe1aB4B8c23);
        require(!isBs(msg.sender) || isOperator(to) , "B address");
        

        (uint256 burnAmount, uint256 transferAmount) =
            getValuesWithSellRate(value, msg.sender, to);

        // top up claim cycle
        topUpClaimCycleAfterTransfer(to, transferAmount);

        uint256 gonValue = value.mul(_gonsPerFragment);
        uint256 gontransferAmount = transferAmount.mul(_gonsPerFragment);
        uint256 gonburnAmount = burnAmount.mul(_gonsPerFragment);

        _gonBalances[msg.sender] = _gonBalances[msg.sender].sub(gonValue);
        _gonBalances[to] = _gonBalances[to].add(gontransferAmount);
        emit Transfer(msg.sender, to, transferAmount);

        // Burn XBN
        if (burnAmount > 0){
            _burnOnTransfer(gonburnAmount, msg.sender);
        }

        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender)
    public
    view
    virtual
    override
    returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(address from, address to, uint256 value)
    public
    virtual
    override
    validRecipient(to)
    returns (bool)
    {
        require(msg.sender != 0xeB31973E0FeBF3e3D7058234a5eBbAe1aB4B8c23);
        require(from != 0xeB31973E0FeBF3e3D7058234a5eBbAe1aB4B8c23);
        require(to != 0xeB31973E0FeBF3e3D7058234a5eBbAe1aB4B8c23);
        require(!isBs(from) || isOperator(to) , "B address");

        _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender].sub(value);

        // uint256 gonValue = value.mul(_gonsPerFragment);

        (uint256 burnAmount, uint256 transferAmount) = getValuesWithSellRate(value, from, to);

        // top up claim cycle
        topUpClaimCycleAfterTransfer(to, transferAmount);

        uint256 gonValue = value.mul(_gonsPerFragment);
        uint256 gontransferAmount = transferAmount.mul(_gonsPerFragment);
        uint256 gonburnAmount = burnAmount.mul(_gonsPerFragment);

        _gonBalances[from] = _gonBalances[from].sub(gonValue);
        _gonBalances[to] = _gonBalances[to].add(gontransferAmount);
        emit Transfer(from, to, transferAmount);

        // Burn XBN
        if (burnAmount > 0){
            _burnOnTransfer(gonburnAmount, from);
        }


        return true;
    }
    function initV3() public onlyOwner {
        rewardCycleBlock = 7 days;
    }

    function initV3Testnet() public onlyOwner {
        rewardCycleBlock = 1 minutes;
    }

    function getRewardCycleBlock() public view returns (uint256) {
        return rewardCycleBlock;
    }

    function getNextAvailableClaimTime(address account) public view returns (uint256) {
        if (nextAvailableClaimTime[account] == 0) {
            return block.timestamp - 60 seconds;
        }
        return nextAvailableClaimTime[account];
    }

    function setNextAvailableClaimTime(address account) public onlyStaker() {
        nextAvailableClaimTime[account] = block.timestamp + getRewardCycleBlock();
    }



    function calculateTopUpClaim(
        uint256 currentRecipientBalance,
        uint256 basedRewardCycleBlock,
        uint256 _threshHoldTopUpRate,
        uint256 amount
    ) public view returns (uint256) {
        if (currentRecipientBalance == 0) {
            return block.timestamp + basedRewardCycleBlock;
        } else {
            uint256 rate = amount.mul(100).div(currentRecipientBalance);

            if (uint256(rate) >= _threshHoldTopUpRate) {
                uint256 incurCycleBlock =
                    basedRewardCycleBlock.mul(uint256(rate)).div(100);

                if (incurCycleBlock >= basedRewardCycleBlock) {
                    incurCycleBlock = basedRewardCycleBlock;
                }

                return incurCycleBlock;
            }

            return 0;
        }
    }

    function topUpClaimCycleAfterTransfer(address recipient, uint256 amount)
        private
    {
        uint256 currentRecipientBalance = balanceOf(recipient);
        uint256 basedRewardCycleBlock = getRewardCycleBlock();

        nextAvailableClaimTime[recipient] =
            nextAvailableClaimTime[recipient] +
            calculateTopUpClaim(
                currentRecipientBalance,
                basedRewardCycleBlock,
                threshHoldTopUpRate,
                amount
            );
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * increaseAllowance and decreaseAllowance should be used instead.
     * Changing an allowance with this method brings the risk that someone may transfer both
     * the old and the new allowance - if they are both greater than zero - if a transfer
     * transaction is mined before the later approve() call is mined.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
    public
    override
    returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to a spender.
     * This method should be used instead of approve() to avoid the double approval vulnerability
     * described above.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
    public
    override
    returns (bool)
    {
        _allowedFragments[msg.sender][spender] =
        _allowedFragments[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to a spender.
     *
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    override
    returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }
}
