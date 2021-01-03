import "../lib/ERC20.sol";

contract MockERC20 is ERC20UpgradeSafe {
    constructor(uint256 _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
