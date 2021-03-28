pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";

interface Dealer {
    function exchangeToken() external payable;
}

contract QuestAirdrop {
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

    mapping(uint256 => QuestRewardCode) private rewardCodeMetadata;
    mapping(uint256 => uint256) private codeMapping;
    uint256 private rewardCodeLength = 0;
    Dealer private dealer;

    modifier onlyOwner() {
        require(msg.sender == owner, 'Error: Only owner can handle this operation ;)');
        _;
    }

    constructor(
        address _tokenInstance,
        uint256 _bonusMinRate,
        uint256 _bonusMaxRate,
        address _happyDealerAddress
    ) public {
        // set distribution token address
        require(_tokenInstance != address(0), 'Error: cannot add token at NoWhere :)');
        tokenInstance = ERC20UpgradeSafe(_tokenInstance);

        // set owner
        owner = msg.sender;

        // set next period wait time
        setBonusRate(_bonusMinRate, _bonusMaxRate);

        // set dealer
        setDealer(_happyDealerAddress);
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function setDealer(address dealerAddress) public onlyOwner {
        dealer = Dealer(dealerAddress);
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

    function generateQuestCode(uint256 quantity, uint256 amount) public onlyOwner {
        for (uint i = 0; i < quantity; i++) {
            uint256 hash = random(0, 10 ether, rewardCodeLength);
            rewardCodeMetadata[hash].claimableAmount = amount;
            rewardCodeMetadata[hash].status = 1;
            rewardCodeMetadata[hash].rewardCode = hash;
            rewardCodeMetadata[hash].createdAt = block.timestamp;

            codeMapping[rewardCodeLength] = hash;
            rewardCodeLength++;
        }
    }

    function getQuestCodeLength() public view onlyOwner returns (uint256){
        return rewardCodeLength;
    }

    function getCodeMetaData(uint256 rewardCodeIndex) public view onlyOwner returns (QuestRewardCode memory) {
        uint256 hash = codeMapping[rewardCodeIndex];
        return rewardCodeMetadata[hash];
    }

    function verifyRewardCode(uint256 rewardCode) private view {
        require(rewardCodeMetadata[rewardCode].status == 1, 'Error: The code is invalid');
        require(rewardCodeMetadata[rewardCode].claimedBy == address(0x00), 'Error: The code is invalid');
        require(rewardCodeMetadata[rewardCode].rewardCode != 0, 'Error: The code is invalid');
        require(rewardCodeMetadata[rewardCode].claimableAmount != 0, 'Error: The code is invalid');
    }

    function onRewardCodeClaimed(uint256 rewardCode) private {
        rewardCodeMetadata[rewardCode].status = 0;
        rewardCodeMetadata[rewardCode].claimedBy = msg.sender;
        rewardCodeMetadata[rewardCode].claimedAt = block.timestamp;
    }

    function claimRewardCode(uint256 rewardCode) public payable {
        require(msg.value >= 0, 'Error: empty tax is not allowed');

        verifyRewardCode(rewardCode);

        // now have some fun, maybe users will receive more than standard rewards
        uint256 claimableAmount = rewardCodeMetadata[rewardCode].claimableAmount;
        uint256 bonusRate = calculateBonusRate();
        uint256 actualReward = claimableAmount.mul(bonusRate).div(100);

        int256 remainingFund = int256(
            tokenInstance.balanceOf(address(this))
        ) - int256(actualReward);

        require(
            remainingFund > 0,
            'Error: contract fund is exceeded'
        );

        tokenInstance.transfer(msg.sender, actualReward);

        onRewardCodeClaimed(rewardCode);

        dealer.exchangeToken{value: msg.value}();
    }

    function emergencyWithdraw() public onlyOwner {
        tokenInstance.transfer(
            msg.sender,
            tokenInstance.balanceOf(address(this))
        );
    }
}
