pragma solidity >=0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";

contract MysticDealer {
    using SafeMath for uint256;

    /* ************ */
    /* Defined structs */
    /* ************ */

    struct OrderInformation {
        uint256 price;
        address buyer;
        uint256 bonus;
        uint256 timestamp;
        uint256 purchasedTokenAmount;
    }

    struct OrderMeta {
        uint256 luckyNumber;
        uint256 participantWaitTime;
    }

    /* ************ */
    /* Defined purchased order information */
    /* ************ */

    // Transparently store successfully order information
    OrderInformation[] private orderBook;

    // Order meta rules
    mapping(address => OrderMeta) private orderMeta;

    /* ************ */
    /* Interface to interact with the token */
    /* ************ */

    ERC20UpgradeSafe private tokenInstance;

    /* ************ */
    /* Defined privileged information */
    /* ************ */

    // Contract privileged owner
    address private owner;

    // The owner can withdraw ETH and transfer to the team's fund address
    address payable private foundationAddress;

    /* ************ */
    /* Defined rules */
    /* ************ */

    // Participant time rule
    uint256 private purchasePeriodWaitTime; // in sec value

    // Quantity rules

    // 1 ETH = exchanged tokens
    uint256 private exchangeRate;

    // both in ETH value
    uint256 private minBidAmount;
    uint256 private maxBidAmount;

    constructor(
        address _tokenInstance,
        uint256 _foundationAddress,
        uint256 _purchasePeriodWaitTime,
        uint256 _exchangeRate,
        uint256 _minBidAmount,
        uint256 _maxBidAmount
    ) public {
        // set owner
        owner = msg.sender;

        // set distribution token address
        require(_tokenInstance != address(0), 'Error: cannot add token at NoWhere :)');
        tokenInstance = ERC20UpgradeSafe(_tokenInstance);

        // set foundation address
        setFoundationAddress(_foundationAddress);

        // set purchase period wait time
        setPurchasePeriodWaitTime(_purchasePeriodWaitTime);

        // set quantity rules
        setQuantityRules(_exchangeRate, _minBidAmount, _maxBidAmount);
    }

    function setFoundationAddress(address payable _foundationAddress) public {
        require(
            owner == msg.sender,
            'Error: only owner can adjust purchase period wait time'
        );
        require(_foundationAddress != address(0), 'Error: cannot add address at NoWhere :)');

        foundationAddress = _foundationAddress;
    }

    function setPurchasePeriodWaitTime(uint256 _purchasePeriodWaitTime) public {
        require(
            owner == msg.sender,
            'Error: only owner can adjust purchase period wait time'
        );
        require(uint256(_purchasePeriodWaitTime) >= 1 minutes, 'Error: purchase period wait time must be at least 1 minute');

        purchasePeriodWaitTime = uint256(_purchasePeriodWaitTime);
    }

    function setQuantityRules(
        uint256 _exchangeRate,
        uint256 _minBidAmount,
        uint256 _maxBidAmount
    ) public {
        // validate input
        require(
            owner == msg.sender,
            'Error: only owner can adjust purchase period wait time'
        );
        require(uint256(_minBidAmount) > 0, 'Error: min bid amount cannot be zero');
        require(uint256(_maxBidAmount) >= _minBidAmount, 'Error: max bid amount must be greater than or equal min bid amount');
        require(uint256(_exchangeRate) > 0, 'Error: exchange rate cannot be zero');

        // set data
        minBidAmount = uint256(_minBidAmount).mul(1 ether);
        maxBidAmount = uint256(_maxBidAmount).mul(1 ether);

        // number of tokens will be exchanged per 1 ether
        uint256 decimals = uint256(tokenInstance.decimals());
        exchangeRate = uint256(exchangeRate.mul(10 ** decimals));
    }

    function getOrderMetaOf(address who) public view returns (uint256){
        return orderMeta[who];
    }

    function getOrderBook() public view returns (OrderInformation){
        return orderBook;
    }

    function getRandom(uint256 from, uint256 to) private view returns (uint256) {
        uint256 randomHash = uint256(
            keccak256(
                abi.encodePacked(block.difficulty, now)
            )
        );
        uint256 bonusRate = randomHash.mod(to - from) + from;
        return bonusRate;
    }
//
//    function exchangeToken() public payable costs(price) {
//        // now have some fun, maybe users will receive more than standard rewards
////        uint256 bonusRate = calculateBonusRate();
////        uint256 actualReward = claimableAmount.mul(bonusRate).div(100);
//
//        OrderMeta buyerOrderMeta = getOrderMetaOf(msg.sender);
//        OrderInformation orderInfo = OrderInformation();
//
//        int256 remainingFund = int256(
//            tokenInstance.balanceOf(address(this))
//        ) - int256(actualReward);
//
//        require(
//            remainingFund > 0,
//            'Error: contract fund is exceeded'
//        );
//
//        require(
//            participantWaitTime[msg.sender] <= block.timestamp,
//            'Error: participant wait time is not reached'
//        );
//
//        tokenInstance.transfer(msg.sender, actualReward);
//        participantWaitTime[msg.sender] = block.timestamp + nextPeriodWaitTime;
//    }
}
