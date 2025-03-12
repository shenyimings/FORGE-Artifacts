// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IConverter.sol";

/**
 * @title Converter between certain assets pairs.
 */
contract Converter is IConverter, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event AccessUpdated(address indexed _account, bool _approved);

    address public constant BADGER_RENCRV = address(0x6dEf55d2e18486B9dDfaA075bc4e4EE0B28c1545);
    address public constant RENCRV = address(0x49849C98ae39Fff122806C06791Fa73784FB3675);

    // The address that is allowed to invoke the converter.
    mapping(address => bool) public approved;

    /**
     * @dev Initializes the converter contract.
     */
    function initialize() public initializer {
        __Ownable_init();
    }

    /**
     * @dev Core function to handle asset conversion.
     */
    function convert(address _from, address _to, uint256 _fromAmount, uint256 _toAmount) external override {
        require(approved[msg.sender], "not approved");
        // Will update when more asset pairs are supported
        require(_from == RENCRV && _to == BADGER_RENCRV, "not supported");

        IERC20Upgradeable(_from).safeTransferFrom(msg.sender, address(this), _fromAmount);
        IERC20Upgradeable(_to).safeTransfer(msg.sender, _toAmount);
    }

    /**
     * @dev Updates the access of the account. Only owner can update access.
     */
    function updateAccess(address _account, bool _approved) external onlyOwner {
        approved[_account] = _approved;

        emit AccessUpdated(_account, _approved);
    }

    /**
     * @dev Withdraws asset from the converter. Only owner can withdraw.
     */
    function withdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount);
    }
}