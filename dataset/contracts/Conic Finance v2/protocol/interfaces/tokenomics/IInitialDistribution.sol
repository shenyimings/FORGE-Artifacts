// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../libraries/MerkleProof.sol";

interface IInitialDistribution {
    event DistributonStarted();
    event DistributonEnded();
    event TokenDistributed(address receiver, uint256 receiveAmount, uint256 amountDeposited);

    function getAmountForDeposit(uint256 depositAmount) external view returns (uint256);

    function getDefaultMinOutput(uint256 depositAmount) external view returns (uint256);

    function getLeftInTranche() external view returns (uint256);

    function ape(uint256 minOutputAmount) external payable;

    function ape(uint256 minOutputAmount, MerkleProof.Proof calldata proof) external payable;

    function start() external;

    function end() external;
}
