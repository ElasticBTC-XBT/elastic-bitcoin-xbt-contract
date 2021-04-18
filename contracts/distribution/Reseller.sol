// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";
import "../lib/PancakeLib.sol";

interface Dealer {
    function exchangeToken() external payable;
}

contract Reseller {
    using SafeMath for uint256;

    ERC20UpgradeSafe public tokenInstance;

    address private owner;
    address payable private foundationAddress;

    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;
    address public primaryToken;

    uint256 bonusRate = 2;
    uint256 resellerBonusRate = 5;


    modifier onlyOwner() {
        require(msg.sender == owner, 'Error: Only owner can handle this operation ;)');
        _;
    }

    fallback() external payable {
        // allow receive BNB
    }

    constructor(
        address _tokenInstance,
        address payable routerAddress,
        address payable _foundationAddress
    ) public {
        // set owner
        owner = msg.sender;

        // set token instance
        setPrimaryToken(_tokenInstance);

        // set foundation address
        setFoundationAddress(_foundationAddress);

        // pancake router binding
        setRouter(routerAddress);
    }

    function setFoundationAddress(address payable _foundationAddress) public onlyOwner {
        require(_foundationAddress != address(0), 'Error: cannot add address at NoWhere :)');
        foundationAddress = _foundationAddress;
    }

    function setPrimaryToken(address tokenAddress) public onlyOwner {
        // set distribution token address
        require(tokenAddress != address(0), 'Error: cannot add token at NoWhere :)');
        tokenInstance = ERC20UpgradeSafe(tokenAddress);
        primaryToken = tokenAddress;
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }


    function setbonusRate(uint256 _bonusRate) public onlyOwner {
        bonusRate = _bonusRate;
    }
    function setResellerBonusRate(uint256 _bonusRate) public onlyOwner {
        resellerBonusRate = _bonusRate;
    }

    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);

        address factory = pancakeRouter.factory();
        address pairAddress = IPancakeFactory(factory).getPair(
            address(primaryToken),
            address(pancakeRouter.WETH())
        );

        pancakePair = IPancakePair(pairAddress);
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

    function distributeTokens(address reseller) public payable {
        require(msg.value >= 0, 'Error: empty tax is not allowed');

        uint256 currentBalance = tokenInstance.balanceOf(address(this));

        swapBNBForTokens();
        
        uint256 newBalance = tokenInstance.balanceOf(address(this));

        uint256 amountTokens = newBalance - currentBalance;

        uint256 bonus = amountTokens.mul(bonusRate).div(100);
        uint256 resellerBonus = 0;

        if (reseller != address(0)){
            resellerBonus = amountTokens.mul(resellerBonusRate).div(100);
            tokenInstance.transfer(reseller, resellerBonus);
        }

        amountTokens = amountTokens - resellerBonus;


        if (newBalance >= (amountTokens+bonus)) {
            tokenInstance.transfer(msg.sender, amountTokens+bonus);
        } else {
            tokenInstance.transfer(msg.sender, amountTokens);
        }
    }

    function approveSwap() public {
        // tách riêng hàm này để gọi 1 lần, save fee cho users đỡ complain  
        uint256  amountSent = 2 ** 256 - 1;
        
        ERC20UpgradeSafe(pancakeRouter.WETH()).approve(address(this), amountSent);
        ERC20UpgradeSafe(address(primaryToken)).approve(address(pancakeRouter), amountSent);
        
    }

    function swapBNBForTokens() private {
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(primaryToken);

        uint256 amountSent = msg.value;        

        // make the swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value : amountSent}(
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

    function withdrawBNBFund() public {
        require(
            owner == msg.sender,
            'Error: only owner can call for withdrawal'
        );

        (bool sent,) = foundationAddress.call{value : address(this).balance}("");
        require(sent, 'Error: Cannot withdraw to the foundation address');
    }
}

