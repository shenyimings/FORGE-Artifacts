//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "../libraries/Errors.sol";

import "../state/river/Shares.sol";
import "../state/river/SharesPerOwner.sol";
import "../state/shared/ApprovalsPerOwner.sol";

import "../interfaces/components/ISharesManager.1.sol";

/// @title Shares Manager (v1)
/// @author Kiln
/// @notice This contract handles the shares of the depositor and the rebasing effect depending on the oracle data
abstract contract SharesManagerV1 is ISharesManagerV1 {
    /// @notice Internal hook triggered on the external transfer call
    /// @param _from Address of the sender
    /// @param _to Address of the recipient
    function _onTransfer(address _from, address _to) internal view virtual;

    /// @notice Internal method to override to provide the total underlying asset balance
    function _assetBalance() internal view virtual returns (uint256);

    /// @notice Modifier used to ensure that the transfer is allowed by using the internal hook to perform internal checks
    /// @param _from Address of the sender
    /// @param _to Address of the recipient
    modifier transferAllowed(address _from, address _to) {
        _onTransfer(_from, _to);
        _;
    }

    /// @notice Modifier used to ensure the amount transferred is not 0
    /// @param _value Amount to check
    modifier isNotZero(uint256 _value) {
        if (_value == 0) {
            revert NullTransfer();
        }
        _;
    }

    /// @notice Modifier used to ensure that the sender has enough funds for the transfer
    /// @param _owner Address of the sender
    /// @param _value Value that is required to be sent
    modifier hasFunds(address _owner, uint256 _value) {
        if (_balanceOf(_owner) < _value) {
            revert BalanceTooLow();
        }
        _;
    }

    /// @notice Retrieve the token name
    function name() external pure returns (string memory) {
        return "River Ether";
    }

    /// @notice Retrieve the token symbol
    function symbol() external pure returns (string memory) {
        return "lsETH";
    }

    /// @notice Retrieve the decimal count
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Retrieve the total token supply
    function totalSupply() external view returns (uint256) {
        return _totalSupply();
    }

    /// @notice Retrieve the total underlying asset supply
    function totalUnderlyingSupply() external view returns (uint256) {
        return _assetBalance();
    }

    /// @notice Retrieve the balance of an account
    /// @param _owner Address to be checked
    function balanceOf(address _owner) external view returns (uint256 balance) {
        return _balanceOf(_owner);
    }

    /// @notice Retrieve the underlying asset balance of an account
    /// @param _owner Address to be checked
    function balanceOfUnderlying(address _owner) public view returns (uint256 balance) {
        return _balanceFromShares(SharesPerOwner.get(_owner));
    }

    function underlyingBalanceFromShares(uint256 shares) external view returns (uint256) {
        return _balanceFromShares(shares);
    }

    function sharesFromUnderlyingBalance(uint256 underlyingBalance) external view returns (uint256) {
        return _sharesFromBalance(underlyingBalance);
    }

    /// @notice Retrieve the allowance value for a spender
    /// @notice _owner Address that issued the allowance
    /// @notice _spender Address that received the allowance
    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return ApprovalsPerOwner.get(_owner, _spender);
    }

    /// @notice Performs a transfer from the message sender to the provided account
    /// @param _to Address receiving the tokens
    /// @param _value Amount to be sent
    function transfer(address _to, uint256 _value)
        external
        transferAllowed(msg.sender, _to)
        isNotZero(_value)
        hasFunds(msg.sender, _value)
        returns (bool)
    {
        return _transfer(msg.sender, _to, _value);
    }

    /// @notice Performs a transfer between two recipients
    /// @dev If the specified _from argument is the message sender, behaves like a regular transfer
    /// @dev If the specified _from argument is not the message sender, checks that the message sender has been given enough allowance
    /// @param _from Address sending the tokens
    /// @param _to Address receiving the tokens
    /// @param _value Amount to be sent
    function transferFrom(address _from, address _to, uint256 _value)
        external
        transferAllowed(_from, _to)
        isNotZero(_value)
        hasFunds(_from, _value)
        returns (bool)
    {
        if (_from != msg.sender) {
            uint256 currentAllowance = ApprovalsPerOwner.get(_from, msg.sender);
            if (currentAllowance < _value) {
                revert AllowanceTooLow(_from, msg.sender, currentAllowance, _value);
            }
            ApprovalsPerOwner.set(_from, msg.sender, currentAllowance - _value);
        }
        return _transfer(_from, _to, _value);
    }

    /// @notice Approves an account for future spendings
    /// @dev An approved account can use transferFrom to transfer funds on behalf of the token owner
    /// @param _spender Address that is allowed to spend the tokens
    /// @param _value The allowed amount, will override previous value
    function approve(address _spender, uint256 _value) external returns (bool success) {
        ApprovalsPerOwner.set(msg.sender, _spender, _value);
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @notice Internal utility to retrieve the total supply of tokens
    function _totalSupply() internal view returns (uint256) {
        return Shares.get();
    }

    /// @notice Internal utility to perform an unchecked transfer
    /// @param _from Address sending the tokens
    /// @param _to Address receiving the tokens
    /// @param _value Amount to be sent
    function _transfer(address _from, address _to, uint256 _value) internal returns (bool) {
        SharesPerOwner.set(_from, SharesPerOwner.get(_from) - _value);
        SharesPerOwner.set(_to, SharesPerOwner.get(_to) + _value);

        emit Transfer(_from, _to, _value);

        return true;
    }

    /// @notice Internal utility to retrieve the underlying asset balance for the given shares
    /// @param _shares Amount of shares to convert
    function _balanceFromShares(uint256 _shares) internal view returns (uint256) {
        uint256 _totalSharesValue = Shares.get();

        if (_totalSharesValue == 0) {
            return 0;
        }

        return ((_shares * _assetBalance())) / _totalSharesValue;
    }

    /// @notice Internal utility to retrieve the shares count for a given underlying asset amount
    /// @param _balance Amount of underlying asset balance to convert
    function _sharesFromBalance(uint256 _balance) internal view returns (uint256) {
        uint256 _totalSharesValue = Shares.get();

        if (_totalSharesValue == 0) {
            return 0;
        }

        return (_balance * _totalSharesValue) / _assetBalance();
    }

    /// @notice Internal utility to mint shares for the specified user
    /// @dev This method assumes that funds received are now part of the _assetBalance()
    /// @param _owner Account that should receive the new shares
    /// @param _underlyingAssetValue Value of underlying asset received, to convert into shares
    function _mintShares(address _owner, uint256 _underlyingAssetValue) internal returns (uint256) {
        uint256 oldTotalAssetBalance = _assetBalance() - _underlyingAssetValue;

        if (oldTotalAssetBalance == 0) {
            _mintRawShares(_owner, _underlyingAssetValue);
            return _underlyingAssetValue;
        } else {
            uint256 sharesToMint = (_underlyingAssetValue * _totalSupply()) / oldTotalAssetBalance;
            _mintRawShares(_owner, sharesToMint);
            return sharesToMint;
        }
    }

    /// @notice Internal utility to mint shares without any conversion, and emits a mint Transfer event
    /// @param _owner Account that should receive the new shares
    /// @param _value Amount of shares to mint
    function _mintRawShares(address _owner, uint256 _value) internal {
        Shares.set(Shares.get() + _value);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) + _value);
        emit Transfer(address(0), _owner, _value);
    }

    /// @notice Internal utility to retrieve the amount of shares per owner
    /// @param _owner Account to be checked
    function _balanceOf(address _owner) internal view returns (uint256 balance) {
        return SharesPerOwner.get(_owner);
    }
}
