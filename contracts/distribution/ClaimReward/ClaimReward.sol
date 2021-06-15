pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "../../lib/ERC20.sol";
import "./lib/Utils.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";

interface XBN is IERC20 {
    function getNextAvailableClaimTime(address account)
        external
        view
        returns (uint256);
}

contract ClaimReward {
    using SafeMath for uint256;

    XBN public tokenInstance;

    address private owner;
    address payable private foundationAddress;
    address public primaryToken;
    address public _busdAddress;

    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 public rewardThreshold;
    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;

    uint256 bonusRate = 2;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Error: Only owner can handle this operation ;)"
        );
        _;
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

    function setFoundationAddress(address payable _foundationAddress)
        public
        onlyOwner
    {
        require(
            _foundationAddress != address(0),
            "Error: cannot add address at NoWhere :)"
        );
        foundationAddress = _foundationAddress;
    }

    function setPrimaryToken(address tokenAddress) public onlyOwner {
        // set distribution token address
        require(
            tokenAddress != address(0),
            "Error: cannot add token at NoWhere :)"
        );
        tokenInstance = XBN(tokenAddress);
        primaryToken = tokenAddress;
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function setBonusRate(uint256 _bonusRate) public onlyOwner {
        bonusRate = _bonusRate;
    }

    function setRewardThreshold(uint256 _rewardThreshold) public onlyOwner {
        rewardThreshold = _rewardThreshold;
    }

    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);

        address factory = pancakeRouter.factory();
        address pairAddress =
            IPancakeFactory(factory).getPair(
                address(primaryToken),
                address(pancakeRouter.WETH())
            );

        pancakePair = IPancakePair(pairAddress);
    }

    function random(
        uint256 from,
        uint256 to,
        uint256 salty
    ) private view returns (uint256) {
        uint256 seed =
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp +
                            block.difficulty +
                            ((
                                uint256(
                                    keccak256(abi.encodePacked(block.coinbase))
                                )
                            ) / (now)) +
                            block.gaslimit +
                            ((
                                uint256(keccak256(abi.encodePacked(msg.sender)))
                            ) / (now)) +
                            block.number +
                            salty
                    )
                )
            );
        return seed.mod(to - from) + from;
    }

    function isLotteryWon(uint256 salty, uint256 winningDoubleRewardPercentage)
        private
        view
        returns (bool)
    {
        uint256 luckyNumber = random(0, 100, salty);
        uint256 winPercentage = winningDoubleRewardPercentage;
        return luckyNumber <= winPercentage;
    }

    function calculateBNBReward(
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 winningDoubleRewardPercentage,
        uint256 _totalSupply
    )
        public
        view
        returns (
            // address ofAddress
            uint256
        )
    {
        uint256 bnbPool = currentBNBPool;

        // calculate reward to send
        bool isLotteryWonOnClaim =
            isLotteryWon(currentBalance, winningDoubleRewardPercentage);
        uint256 multiplier = 100;

        if (isLotteryWonOnClaim) {
            multiplier = random(150, 200, currentBalance);
        }

        // now calculate reward
        uint256 reward =
            bnbPool.mul(multiplier).mul(currentBalance).div(100).div(
                _totalSupply
            );

        return reward;
    }

    function calculateTokenReward(
        //  uint256 _tTotal,
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 winningDoubleRewardPercentage,
        uint256 _totalSupply,
        // address ofAddress,
        address routerAddress,
        address tokenAddress
    ) public view returns (uint256) {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        // ETH Address
        // path[1] = address(0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378);
        path[1] = tokenAddress;

        uint256 bnbReward =
            calculateBNBReward(
                // _tTotal,
                currentBalance,
                currentBNBPool,
                winningDoubleRewardPercentage,
                _totalSupply
                // ofAddress
            );

        return pancakeRouter.getAmountsOut(bnbReward, path)[1];
    }

    function getNextClaimTime(address account) public view returns (uint256) {
        return tokenInstance.getNextAvailableClaimTime(account);
    }
    function claimTokenReward(address tokenAddress, bool taxing) private {
        require(
            tokenInstance.getNextAvailableClaimTime(msg.sender) <= block.timestamp,
            "Error: next available not reached"
        );
        require(
            tokenInstance.balanceOf(msg.sender) > 0,
            "Error: must own PEPE to claim reward"
        );

        // uint256 reward = UtilsXBN.calculateBNBReward(msg.sender);

        // // reward threshold
        // if (reward >= rewardThreshold && taxing) {
        //     UtilsXBN.swapETHForTokens(
        //         address(pancakeRouter),
        //         address(0x000000000000000000000000000000000000dEaD),
        //         reward.div(3)
        //     );
        //     reward = reward.sub(reward.div(3));
        // } else {
        //     // burn 10% if not claim XBN or PEPE
        //     if ( tokenAddress == _busdAddress) {
        //         UtilsXBN.swapETHForTokens(
        //             address(pancakeRouter),
        //             address(0x000000000000000000000000000000000000dEaD),
        //             reward.div(7)
        //         );
        //         reward = reward.sub(reward.div(7));
        //     }
        // }

        // // update rewardCycleBlock
        // nextAvailableClaimDate[msg.sender] =
        //     block.timestamp +
        //     getRewardCycleBlock();
        // emit ClaimBNBSuccessfully(
        //     msg.sender,
        //     reward,
        //     nextAvailableClaimDate[msg.sender]
        // );
        // UtilsXBN.swapBNBForToken(
        //     address(pancakeRouter),
        //     tokenAddress,
        //     address(msg.sender),
        //     reward
        // );
    }
}
