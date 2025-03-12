// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IPlatformFee {
    /// @dev Returns the platform fee bps and recipient.
    function getPlatformFeeInfo()
        external
        view
        returns (
            address,
            uint16,
            uint16
        );

    /// @dev Lets a module admin update the fees on primary sales.
    function setPlatformFeeInfo(
        address _platformFeeRecipient,
        uint256 _tevanPlatformFeeBps,
        uint256 _nonTevanPlatformFeeBps
    ) external;

    /// @dev Emitted when fee on primary sales is updated.
    event PlatformFeeInfoUpdated(
        address indexed platformFeeRecipient,
        uint256 tevanPlatformFeeBps,
        uint256 nonTevanPlatformFeeBps
    );
}
