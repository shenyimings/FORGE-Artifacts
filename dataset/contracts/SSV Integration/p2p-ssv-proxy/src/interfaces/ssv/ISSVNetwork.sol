// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;
import "./ISSVClusters.sol";

/// @dev https://github.com/bloxapp/ssv-network/blob/8c945e82cc063eb8e40c467d314a470121821157/contracts/interfaces/ISSVNetwork.sol
interface ISSVNetwork is ISSVClusters {
    function setFeeRecipientAddress(address feeRecipientAddress) external;
}
