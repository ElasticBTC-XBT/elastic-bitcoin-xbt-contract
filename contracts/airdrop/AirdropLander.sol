pragma solidity >=0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";

contract AirdropLander {
    using SafeMath for uint256;

    ERC20UpgradeSafe public tokenInstance;
    uint256 public claimableAmount;
    mapping(address => uint256) public participantWaitTime;
    address private owner;
    uint256 private nextPeriodWaitTime; // in sec value
    uint256 private bonusMinRate;
    uint256 private bonusMaxRate;

    constructor(
        address _tokenInstance,
        uint256 _claimableAmount,
        uint256 _nextPeriodWaitTime,
        uint256 _bonusMinRate,
        uint256 _bonusMaxRate
    ) public {
        require(_tokenInstance != address(0), 'Error: cannot add token at NoWhere :)');

        // set distribution token address
        tokenInstance = ERC20UpgradeSafe(_tokenInstance);

        // set owner
        owner = msg.sender;

        // set claimable amount
        setClaimableAmount(_claimableAmount);

        // set next period wait time
        setNextPeriodWaitTime(_nextPeriodWaitTime);

        // set next period wait time
        setBonusRate(_bonusMinRate, _bonusMaxRate);
    }

    function setBonusRate(uint256 from, uint256 to) public {
        require(
            owner == msg.sender,
            'Error: only owner can adjust bonus rate'
        );

        require(
            uint256(from) < uint256(to),
            'Error: from value must be less than to value'
        );

        // set bonus rate
        bonusMinRate = uint256(from);
        bonusMaxRate = uint256(to);
    }

    function setNextPeriodWaitTime(uint256 _nextPeriodWaitTime) public {
        require(
            owner == msg.sender,
            'Error: only owner can adjust wait time'
        );
        require(uint256(_nextPeriodWaitTime) >= 1 minutes, 'Error: Wait time should be at least 1 minutes');

        // set next period wait time
        nextPeriodWaitTime = uint256(_nextPeriodWaitTime);
    }

    function setClaimableAmount(uint256 _claimableAmount) public {
        require(
            owner == msg.sender,
            'Error: only owner can adjust claimable amount'
        );
        require(uint256(_claimableAmount) > 0, 'Error: claimable amount cannot be zero');

        uint256 decimals = uint256(tokenInstance.decimals());
        claimableAmount = uint256(_claimableAmount.mul(10 ** decimals));
    }

    function calculateBonusRate() private view returns (uint256) {
        uint256 randomHash = uint256(
            keccak256(
                abi.encodePacked(block.difficulty, now)
            )
        );
        uint256 bonusRate = randomHash.mod(bonusMaxRate - bonusMinRate) + bonusMinRate;
        return bonusRate;
    }

    function participantWaitTimeOf(address who) public view returns (uint256){
        return participantWaitTime[who];
    }

    function requestTokens() public {
        // now have some fun, maybe users will receive more than standard rewards
        uint256 bonusRate = calculateBonusRate();
        uint256 actualReward = claimableAmount.mul(bonusRate).div(100);

        int256 remainingFund = int256(
            tokenInstance.balanceOf(address(this))
        ) - int256(actualReward);

        require(
            remainingFund > 0,
            'Error: contract fund is exceeded'
        );

        require(
            participantWaitTime[msg.sender] <= block.timestamp,
            'Error: participant wait time is not reached'
        );

        tokenInstance.transfer(msg.sender, actualReward);
        participantWaitTime[msg.sender] = block.timestamp + nextPeriodWaitTime;
    }
}
