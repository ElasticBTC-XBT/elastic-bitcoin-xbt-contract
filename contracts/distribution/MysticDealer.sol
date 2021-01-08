pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

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
        address payable _foundationAddress,
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
        minBidAmount = uint256(_minBidAmount);
        maxBidAmount = uint256(_maxBidAmount);

        // number of tokens will be exchanged per 1 ether
        exchangeRate = uint256(_exchangeRate);
    }

    function withdrawFund() public {
        require(
            owner == msg.sender,
            'Error: only owner can call for withdrawal'
        );

        (bool sent,) = foundationAddress.call{value : address(this).balance}("");
        require(sent, 'Error: Cannot withdraw to the foundation address');
    }

    function getOrderMetaOf(address who) public view returns (OrderMeta memory){
        return orderMeta[who];
    }

    function getOrderBook() public view returns (OrderInformation[] memory){
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

    function calculateExchangedAmount(uint256 ethValue) private view returns (uint256, uint256, uint256) {
        require(uint256(ethValue) <= maxBidAmount, 'Error: must be less than max bid amount');
        require(uint256(ethValue) >= minBidAmount, 'Error: must be greater than min bid amount');

        // luckyNumber is a random number from 0,100
        uint256 luckyNumber = getRandom(0, 100);
        uint256 bonusWon = 0;
        uint256 exchangedAmount = uint256(ethValue).mul(exchangeRate).div(1 ether);

        uint256 winPercentage = uint256(ethValue).mul(100).div(1 ether);
        // 0.01 eth = 1 ticket (1% winning rate)
        if (winPercentage > 17) {
            winPercentage = 17;
        }

        if (luckyNumber <= winPercentage) {
            // user wins the lottery, get double return
            bonusWon = exchangedAmount;
        }

        exchangedAmount = exchangedAmount.add(bonusWon);

        return (exchangedAmount, luckyNumber, bonusWon);
    }

    function exchangeToken() private {
        (
        uint256 exchangedAmount,
        uint256 luckyNumber,
        uint256 bonusWon
        ) = calculateExchangedAmount(uint256(msg.value));

        int256 remainingFund = int256(
            tokenInstance.balanceOf(address(this))
        ) - int256(exchangedAmount);

        require(
            remainingFund >= 0,
            'Error: contract fund is exceeded'
        );

        require(
            orderMeta[msg.sender].participantWaitTime <= block.timestamp,
            'Error: participant wait time is not reached'
        );

        tokenInstance.transfer(msg.sender, exchangedAmount);

        // update order info
        OrderInformation memory orderInfo = OrderInformation(0, address(0), 0, 0, 0);
        orderInfo.bonus = bonusWon;
        orderInfo.buyer = msg.sender;
        orderInfo.price = exchangeRate;
        orderInfo.purchasedTokenAmount = exchangedAmount;
        orderInfo.timestamp = block.timestamp;

        // add to order book
        orderBook.push(orderInfo);

        // update buyer meta
        orderMeta[msg.sender].participantWaitTime = block.timestamp + purchasePeriodWaitTime;
        orderMeta[msg.sender].luckyNumber = luckyNumber;
    }

    fallback() external payable {
        //call your function here / implement your actions
        exchangeToken();
    }
}
