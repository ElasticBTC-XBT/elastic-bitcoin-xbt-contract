pragma solidity >=0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../lib/ERC20.sol";

contract AirdropLander {
    using SafeMath for uint256;

    ERC20UpgradeSafe public tokenInstance;
    uint256 public claimableAmount;

    mapping(address => bool) participants;

    constructor(address _tokenInstance, uint256 _claimableAmount) public {
        require(_tokenInstance != address(0), 'Error: cannot add token at NoWhere :)');
        require(uint256(_claimableAmount) > 0, 'Error: claimable amount cannot be zero');

        tokenInstance = ERC20UpgradeSafe(_tokenInstance);

        uint256 decimals = uint256(tokenInstance.decimals());
        claimableAmount = uint256(_claimableAmount * (10 ** decimals));
    }

    function requestTokens() public {
        uint256 remainingFund = tokenInstance.balanceOf(address(this)) - claimableAmount;

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
