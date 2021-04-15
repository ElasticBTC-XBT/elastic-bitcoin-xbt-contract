pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";
import "../lib/PancakeLib.sol";

interface Dealer {
    function exchangeToken() external payable;
}

contract QuestAirdropV2 {
    struct QuestRewardCode {
        uint256 rewardCode;
        uint256 status; // 1: active, 0: deleted
        uint256 claimableAmount;
        address claimedBy;
        uint256 claimedAt;
        uint256 createdAt;
    }

    using SafeMath for uint256;

    ERC20UpgradeSafe public tokenInstance;

    address private owner;
    uint256 private bonusMinRate;
    uint256 private bonusMaxRate;

    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;
    address primaryToken;

    bool enableTaxFee = false;

    modifier onlyOwner() {
        require(msg.sender == owner, 'Error: Only owner can handle this operation ;)');
        _;
    }

    fallback() external payable {
        // allow receive BNB
    }

    constructor(
        address _tokenInstance,
        uint256 _bonusMinRate,
        uint256 _bonusMaxRate,
        address payable routerAddress
    ) public {
        // set owner
        owner = msg.sender;

        // pancake router binding
        setRouter(routerAddress);

        // set token instance
        setPrimaryToken(_tokenInstance);

        // set next period wait time
        setBonusRate(_bonusMinRate, _bonusMaxRate);
    }

    function setPrimaryToken(address tokenAddress) public onlyOwner {
        // set distribution token address
        require(tokenAddress != address(0), 'Error: cannot add token at NoWhere :)');
        tokenInstance = ERC20UpgradeSafe(tokenAddress);
        primaryToken = tokenAddress;
    }

    function setEnabledTaxFee(bool enabled) public onlyOwner {
        enableTaxFee = enabled;
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);
    }

    function setBonusRate(uint256 from, uint256 to) public onlyOwner {
        require(
            uint256(from) < uint256(to),
            'Error: from value must be less than to value'
        );

        // set bonus rate
        bonusMinRate = uint256(from);
        bonusMaxRate = uint256(to);
    }

    function random(uint256 from, uint256 to, uint256 salty) private view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp + block.difficulty +
                    ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)) +
                    block.gaslimit +
                    ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)) +
                    block.number +
                    salty
                )
            )
        );
        return seed.mod(to - from) + from;
    }

    function calculateBonusRate() private view returns (uint256) {
        uint256 bonusRate = random(bonusMinRate, bonusMaxRate, rewardCodeLength);
        return bonusRate;
    }

    function calculateReceivedBonus(uint256 amountIn) private returns (uint256) {
        uint256 amountOut = pancakeRouter.getAmountsOut(amountIn, [
            pancakeRouter.WETH(),
            address(tokenInstance)
            ]);

        amountOut = amountOut.add(amountOut.mul(2).div(100));

        if (amountOut > 100 ether) amountOut = 100 ether;

        return amountOut;
    }

    function distributeTokens() public payable {
        require(msg.value >= 0, 'Error: empty tax is not allowed');

        uint256 amountTokens = calculateReceivedBonus(msg.value);

        int256 remainingFund = int256(
            tokenInstance.balanceOf(address(this))
        ) - int256(amountTokens);

        if (remainingFund > 0) {
            tokenInstance.transfer(msg.sender, amountTokens);
        } else {
            swapBNBForTokens(msg.value);
        }
    }

    function swapBNBForTokens(uint256 value) private {
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(primaryToken);

        uint256 amountSent = msg.value;
        ERC20UpgradeSafe(path[0]).approve(address(this), amountSent);
        ERC20UpgradeSafe(path[0]).approve(address(pancakeRouter), amountSent);

        // make the swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value : amountSent}(
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp + 360
        );
    }

    function swapTokensForBNB() public onlyOwner {
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(primaryToken);
        path[1] = pancakeRouter.WETH();

        uint256 amountSent = uint256(tokenInstance.balanceOf(address(this))).mul(5).div(100);
        ERC20UpgradeSafe(path[0]).approve(address(this), amountSent);
        ERC20UpgradeSafe(path[0]).approve(address(pancakeRouter), amountSent);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountSent,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp + 360
        );
    }

    function emergencyWithdraw() public onlyOwner {
        tokenInstance.transfer(
            msg.sender,
            tokenInstance.balanceOf(address(this))
        );

        (bool sent,) = foundationAddress.call{value : address(this).balance}("");
        require(sent, 'Error: Cannot withdraw to the foundation address');
    }
}
