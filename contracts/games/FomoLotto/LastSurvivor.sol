//SPDX-License-Identifier: Unlicense
pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "hardhat/console.sol";

import "./library/ReentrancyGuard.sol";
import "../../lib/PancakeLib.sol";

contract LastSurvivor is OwnableUpgradeSafe, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public token;

    uint256 public lastBidTime;
    address public lastBidder;


    address public airdropAddress = 0x0000000000000000000000000000000000000000;
    IPancakeRouter02 public pancakeRouter;   // pancake router
    IPancakePair public pancakePair;

    event OnBid(address indexed author, uint256 amount);
    event OnWin(address indexed author, uint256 amount);
    event OnBurn(uint256 amount);

    uint32 public collapseDelay = 888; // 888 seconds 
    uint32 public burnRate = 10; // 10 %

    modifier onlyHuman() {
        require(msg.sender == tx.origin);
        _;
    }

    constructor(address _token) public {
        token = IERC20(_token);
    }
    /**
    * @dev sets the pancake router
    */
    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);

        address factory = pancakeRouter.factory();
        address pairAddress = IPancakeFactory(factory).getPair(
            address(token),
            address(pancakeRouter.WETH())
        );

        pancakePair = IPancakePair(pairAddress);
    }

    function swapBNBForTokens() private {
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(token);

        uint256 amountSent = msg.value;

        // make the swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value : amountSent}(
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp + 360
        );
    }

    function participate(uint256 amount, uint32 slippage, bool useBNB) public onlyHuman payable nonReentrant {
        require(!hasWinner(), "winner, claim first");
        uint256 currentBalance = token.balanceOf(address(this));

        if (useBNB == true) {
            require(msg.value > 0, 'Error: invalid amount');

            swapBNBForTokens();
            uint256 newBalance = token.balanceOf(address(this));
            amount = newBalance - currentBalance;

        }


        require(amount >= currentBalance / 100, "min 1% bid");
        require(amount <= (currentBalance / 100) * (100 + slippage) / 100, "amount exceeds slippage");
        //1% bid with slippage

        uint256 burnAmount = amount / burnRate;
        //10%
        token.safeTransferFrom(msg.sender, airdropAddress, burnAmount);
        token.safeTransferFrom(msg.sender, address(this), amount - burnAmount);

        emit OnBid(msg.sender, amount);
        emit OnBurn(burnAmount);

        lastBidTime = block.timestamp;
        lastBidder = msg.sender;
    }


    function hasWinner() public view returns (bool) {
        return lastBidTime != 0 && block.timestamp - lastBidTime >= collapseDelay;
    }

    function claimReward() public {
        require(hasWinner(), "no winner yet");

        uint256 totalBalance = token.balanceOf(address(this));
        uint256 winAmount = totalBalance / 2;
        //50%
        uint256 nextRoundAmount = totalBalance / 3;
        //33%
        uint256 burnAmount = totalBalance - winAmount - nextRoundAmount;
        //17%

        token.safeTransfer(lastBidder, winAmount);
        token.safeTransfer(airdropAddress, burnAmount);
        lastBidTime = 0;
        emit OnWin(lastBidder, winAmount);
        emit OnBurn(burnAmount);
    }

    function setCollapseDelay(uint32 delay) public onlyOwner {

        require(delay >= 60, "must be at least 1 minute");
        collapseDelay = delay;
    }

    function setburnRate(uint32 rate) public onlyOwner {

        require(rate >= 1, "must be at least 1 ");
        burnRate = rate;
    }


    function setairdropAddress(address _add) public onlyOwner {
        airdropAddress = _add;
    }

    function emergencyWithdraw() public onlyOwner {
        (bool sent,) = (address(msg.sender)).call{value : address(this).balance}("");
        require(sent, 'Error: Cannot withdraw to the foundation address');

        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }


    function setToken(address _token) public onlyOwner {
        token = IERC20(_token);

    }

}