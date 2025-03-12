// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

/// @title Blockscape Events
/// @notice Shared contract for Blockscape Validator and Stake ETH NFTs to define the events
/// @dev This contract is abstract and cannot be deployed
abstract contract BlockscapeEvents {
    /// @dev event for when the NFT stake is updated
    event StakeUpdated(
        uint256 indexed _tokenID,
        address indexed _owner,
        uint256 _newStake
    );

    /// @dev event for when the ETH limit is changed
    event ETHLimitChanged(uint256 _newLimit);

    /// @dev event for when a user requests a withdrawal for a Validator NFT
    event UserRequestedWithdrawalVali(
        uint256 indexed _tokenID,
        address indexed _user,
        uint256 _fee,
        uint256 _stakedETH,
        uint256 _rewards
    );

    /// @dev event for when a user requests a withdrawal for a Stake ETH NFT
    event UserRequestedWithdrawalStake(
        uint256 indexed _tokenID,
        address indexed _user,
        uint256 _stakedETH,
        uint256 _rewards
    );

    /// @dev event for when the RocketPool Node Address is changed
    event RocketPoolNodeAddressChanged(address _newAddress);

    /// @dev event for when the withdraw fee is changed
    event WithdrawFeeChanged (uint256 _newFee);

    /// @dev event for when the timelock for a withdrawal is changed
    event TimelockWithdrawChanged (uint256 _newTimelock);

    /// @dev event for when the vault is opened / closed in case of emergency
    event EmergencyVaultStateChanged (bool _isOpen);
}
