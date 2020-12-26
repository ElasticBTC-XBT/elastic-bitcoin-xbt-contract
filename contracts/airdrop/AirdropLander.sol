pragma solidity >=0.6.8;

import "../lib/ERC20.sol";

contract AirdropLander {
    IERC20 public tokenInstance;
    uint256 public claimableAmount;

    mapping(address => bool) participants;

    constructor(address _tokenInstance, uint256 claimableAmount) public {
        require(_tokenInstance != address(0));
        tokenInstance = IERC20(_tokenInstance);
        claimableAmount = claimableAmount;
    }

    function requestTokens() public {
        require(
            tokenInstance.balanceOf(address(this)) / claimableAmount > 1,
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
