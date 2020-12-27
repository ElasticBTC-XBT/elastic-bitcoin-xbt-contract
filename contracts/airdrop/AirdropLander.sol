pragma solidity >=0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";

contract AirdropLander {
    using SafeMath for uint256;

    ERC20UpgradeSafe public tokenInstance;
    uint256 public claimableAmount;
    mapping(address => bool) participants;
    address private owner;

    constructor(address _tokenInstance, uint256 _claimableAmount) public {
        require(_tokenInstance != address(0), 'Error: cannot add token at NoWhere :)');
        require(uint256(_claimableAmount) > 0, 'Error: claimable amount cannot be zero');

        // set distribution token address
        tokenInstance = ERC20UpgradeSafe(_tokenInstance);

        // set owner
        owner = msg.sender;

        // set claimable amount
        adjustClaimableAmount(_claimableAmount);
    }

    function participantStatusOf(address who) public view returns (bool){
        return participants[who];
    }

    function adjustClaimableAmount(uint256 _claimableAmount) private {
        require(
            owner == msg.sender,
            'Error: only owner can adjust claimable amount'
        );

        uint256 decimals = uint256(tokenInstance.decimals());
        claimableAmount = uint256(_claimableAmount * (10 ** decimals));
    }

    function requestTokens() public {
        int256 remainingFund = int256(tokenInstance.balanceOf(address(this))) - int256(claimableAmount);

        require(
            remainingFund > 0,
            'Error: contract fund is exceeded'
        );

        require(
            participants[msg.sender] == false,
            'Error: participated addresses cannot claim tokens'
        );

        tokenInstance.transfer(msg.sender, claimableAmount);
        participants[msg.sender] = true;
    }
}
