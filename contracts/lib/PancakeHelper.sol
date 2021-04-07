pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./PancakeLib.sol";
import "./ERC20.sol";

contract PancakeHelper {
    using SafeMath for uint256;

    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;

    address primaryToken;
    ERC20UpgradeSafe public tokenInstance;

    address private owner;

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Error: Only owner can handle this operation ;)');
        _;
    }

    fallback() external payable {
        // allow receive BNB
    }

    constructor(address tokenAddress, address payable routerAddress) public {
        owner = msg.sender;

        // set primary token
        setPrimaryToken(tokenAddress);

        // setRouter
        setRouter(routerAddress);
    }

    function setPrimaryToken(address tokenAddress) public onlyOwner {
        // set distribution token address
        require(tokenAddress != address(0), 'Error: cannot add token at NoWhere :)');
        primaryToken = tokenAddress;
        tokenInstance = ERC20UpgradeSafe(tokenAddress);
    }

    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);
    }

    function addLiquidity(bool createPair) public onlyOwner {
        // Create a pancake pair for this new token
        if (createPair) {
            pancakePair = IPancakeFactory(pancakeRouter.factory())
            .createPair(address(primaryToken), pancakeRouter.WETH());
        }

        uint256 amountSent = tokenInstance.balanceOf((address(this)));
        uint256 amountPooledBNB = address(this).balance;

        ERC20UpgradeSafe(address(primaryToken)).approve(address(pancakeRouter), amountSent);
        ERC20UpgradeSafe(pancakeRouter.WETH()).approve(address(pancakeRouter), amountPooledBNB);

        ERC20UpgradeSafe(address(primaryToken)).approve(address(this), amountSent);
        ERC20UpgradeSafe(pancakeRouter.WETH()).approve(address(this), amountPooledBNB);

        // add liquidity
        pancakeRouter.addLiquidityETH{value : amountPooledBNB}(
            primaryToken,
            amountSent,
            0,
            0,
            msg.sender,
            block.timestamp + 10000
        );
    }

    function swapBNBForTokens() public payable {
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
            msg.sender,
            block.timestamp + 360
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) public {
        uint256 initialBalance = ERC20UpgradeSafe(primaryToken).balanceOf(address(this));

        // transfer erc tokens
        ERC20UpgradeSafe(primaryToken).approve(address(this), tokenAmount);
        ERC20UpgradeSafe(primaryToken).transferFrom(msg.sender, address(this), tokenAmount);

        uint256 currentBalance = ERC20UpgradeSafe(primaryToken).balanceOf(address(this));
        uint256 actualAmountSent = currentBalance.sub(initialBalance);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(primaryToken);
        path[1] = pancakeRouter.WETH();

        uint256 amountSent = actualAmountSent;
        ERC20UpgradeSafe(path[0]).approve(address(this), amountSent);
        ERC20UpgradeSafe(path[0]).approve(address(pancakeRouter), amountSent);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountSent,
            0, // accept any amount of BNB
            path,
            msg.sender,
            block.timestamp + 360
        );
    }

    function emergencyWithdraw() public onlyOwner {
        // withdraw balance
        (bool sent,) = address(msg.sender).call{value : address(this).balance}("");
        require(sent, 'Error: Cannot withdraw to the foundation address');

        // transfer tokenInstance
        tokenInstance.transfer(msg.sender, tokenInstance.balanceOf(address(this)));
    }
}
