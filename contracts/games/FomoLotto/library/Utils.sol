pragma solidity >=0.6.8;

import "./SafeMath.sol";

interface IERC20 {
    function withdraw(uint) external;

    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
    * @dev Returns the amount of tokens owned by `account`.
    */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

}

interface IPancakeRouter02 {
    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/// @title Util functions
/// @author hiddenmikasa
library Utils {
    using SafeMath for uint256;

    // The Ether token address is set as the constant 0x00 for backwards
    // compatibility
    address private constant DEFAULT_BNB_ADDR = address(0);

    /// @notice Approves a token transfer
    /// @param _assetId The address of the token to approve
    /// @param _spender The address of the spender to approve
    /// @param _amount The number of tokens to approve
    function approveTokenTransfer(
        address _assetId,
        address _spender,
        uint256 _amount
    )
    public
    {
        _validateContractAddress(_assetId);

        // Some tokens have an `approve` which returns a boolean and some do not.
        // The ERC20 interface cannot be used here because it requires specifying
        // an explicit return value, and an EVM exception would be raised when calling
        // a token with the mismatched return value.
        bytes memory payload = abi.encodeWithSignature(
            "approve(address,uint256)",
            _spender,
            _amount
        );
        bytes memory returnData = _callContract(_assetId, payload);
        // Ensure that the asset transfer succeeded
        _validateContractCallResult(returnData);
    }

    function swapTokensForBNB(
        address routerAddress,
        address primaryToken,
        uint256 amountIn,
        address payable recipient
    ) public {
        uint256 deadline = block.timestamp.add(360);
        IPancakeRouter02 router = IPancakeRouter02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = address(primaryToken);
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(recipient),
            deadline
        );
    }

    function swapBNBForTokens(
        address routerAddress,
        address primaryToken,
        uint256 amountSent,
        address recipient
    ) public {
        IPancakeRouter02 router = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(primaryToken);

        // buy xbn
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value : amountSent}(
            0, // accept any amount of BNB
            path,
            address(recipient),
            block.timestamp + 360
        );
    }

    function chargeXBNFee(
        address routerAddress,
        address primaryToken,
        uint256 taxFeePercentXBN,
        uint256 cappedDeductedBNBFromEarning,
        address airdropFund,
        uint256 depositedBNBValue,
        bool skipTaxCheck
    ) public returns (uint256) {
        // amount sent
        uint256 amountSent = depositedBNBValue;

        if (!skipTaxCheck) {
            // charge fee
            uint256 taxChargedInBNB = uint256(depositedBNBValue).mul(taxFeePercentXBN).div(100);
            if (taxChargedInBNB > cappedDeductedBNBFromEarning) {
                taxChargedInBNB = cappedDeductedBNBFromEarning;
            }
            amountSent = taxChargedInBNB;
        }

        // amount xbn before swap
//        uint256 currentXBNBalance = IERC20(primaryToken).balanceOf((address(this)));

        swapBNBForTokens(address(routerAddress), address(primaryToken), amountSent, address(airdropFund));

//        uint256 balanceAfterSwap = IERC20(primaryToken).balanceOf((address(this)));
//        uint256 delta = balanceAfterSwap.sub(currentXBNBalance);

//        // transfer to airdropFund
//        IERC20(primaryToken).transfer(
//            airdropFund,
//            delta
//        );

        return amountSent;
    }

    /// @notice Transfers tokens into the contract
    /// @param _user The address to transfer the tokens from
    /// @param _assetId The address of the token to transfer
    /// @param _amount The number of tokens to transfer
    /// this may not match `_amount`, for example, tokens which have a
    /// proportion burnt on transfer will have a different amount received.
    function transferTokensIn(
        address _user,
        address _assetId,
        uint256 _amount
    )
    public
    {
        _validateContractAddress(_assetId);

        uint256 initialBalance = tokenBalance(_assetId);

        // Some tokens have a `transferFrom` which returns a boolean and some do not.
        // The ERC20 interface cannot be used here because it requires specifying
        // an explicit return value, and an EVM exception would be raised when calling
        // a token with the mismatched return value.
        bytes memory payload = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            _user,
            address(this),
            _amount
        );
        bytes memory returnData = _callContract(_assetId, payload);
        // Ensure that the asset transfer succeeded
        _validateContractCallResult(returnData);

        uint256 finalBalance = tokenBalance(_assetId);
        uint256 transferredAmount = finalBalance.sub(initialBalance);
    }

    /// @notice Transfers tokens from the contract to a user
    /// @param _receivingAddress The address to transfer the tokens to
    /// @param _assetId The address of the token to transfer
    /// @param _amount The number of tokens to transfer
    function transferTokensOut(
        address _receivingAddress,
        address _assetId,
        uint256 _amount
    )
    public
    {
        _validateContractAddress(_assetId);

        // Some tokens have a `transfer` which returns a boolean and some do not.
        // The ERC20 interface cannot be used here because it requires specifying
        // an explicit return value, and an EVM exception would be raised when calling
        // a token with the mismatched return value.
        bytes memory payload = abi.encodeWithSignature(
            "transfer(address,uint256)",
            _receivingAddress,
            _amount
        );
        bytes memory returnData = _callContract(_assetId, payload);

        // Ensure that the asset transfer succeeded
        _validateContractCallResult(returnData);
    }

    /// @notice Returns the number of tokens owned by this contract
    /// @param _assetId The address of the token to query
    function externalBalance(address _assetId) public view returns (uint256) {
        if (_assetId == DEFAULT_BNB_ADDR) {
            return address(this).balance;
        }
        return tokenBalance(_assetId);
    }

    /// @notice Returns the number of tokens owned by this contract.
    /// @dev This will not work for Ether tokens, use `externalBalance` for
    /// Ether tokens.
    /// @param _assetId The address of the token to query
    function tokenBalance(address _assetId) public view returns (uint256) {
        return IERC20(_assetId).balanceOf(address(this));
    }


    /// @dev A thin wrapper around the native `call` function, to
    /// validate that the contract `call` must be successful.
    /// See https://solidity.readthedocs.io/en/v0.5.1/050-breaking-changes.html
    /// for details on constructing the `_payload`
    /// @param _contract Address of the contract to call
    /// @param _payload The data to call the contract with
    /// @return The data returned from the contract call
    function _callContract(
        address _contract,
        bytes memory _payload
    )
    private
    returns (bytes memory)
    {
        bool success;
        bytes memory returnData;

        (success, returnData) = _contract.call(_payload);
        require(success, "Contract call failed");

        return returnData;
    }

    /// @dev Converts data of type `bytes` into its corresponding `uint256` value
    /// @param _data The data in bytes
    /// @return The corresponding `uint256` value
    function _getUint256FromBytes(
        bytes memory _data
    )
    private
    pure
    returns (uint256)
    {
        uint256 parsed;
        assembly {parsed := mload(add(_data, 32))}
        return parsed;
    }

    /// @dev Fix for ERC-20 tokens that do not have proper return type
    /// See: https://github.com/ethereum/solidity/issues/4116
    /// https://medium.com/loopring-protocol/an-incompatibility-in-smart-contract-threatening-dapp-ecosystem-72b8ca5db4da
    /// https://github.com/sec-bit/badERC20Fix/blob/master/badERC20Fix.sol
    /// @param _data The data returned from a transfer call
    function _validateContractCallResult(bytes memory _data) private pure {
        require(
            _data.length == 0 ||
            (_data.length == 32 && _getUint256FromBytes(_data) != 0),
            "Invalid contract call result"
        );
    }

    /// @dev Ensure that the address is a deployed contract
    /// @param _contract The address to check
    function _validateContractAddress(address _contract) private view {
        assembly {
            if iszero(extcodesize(_contract)) {revert(0, 0)}
        }
    }
}
