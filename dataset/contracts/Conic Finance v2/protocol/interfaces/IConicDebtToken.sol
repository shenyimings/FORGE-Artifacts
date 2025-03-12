// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../libraries/MerkleProof.sol";

interface IConicDebtToken {
    event ClaimPoolSet(address claimPool);
    event RefundClaimed(address claimant, uint256 amount);
    event ClaimingStarted();
    event DebtTokenClaimed(address claimant, uint256 amount);

    function depositRefund(uint256 amount) external;

    function start() external;

    function claimDebtToken(uint256 amount, MerkleProof.Proof calldata proof) external;

    function claimRefund(uint256 amount, MerkleProof.Proof calldata proof) external;

    function claimAll(
        uint256 amountDebtToken,
        MerkleProof.Proof calldata proofDebtTokenClaim,
        uint256 amountRefund,
        MerkleProof.Proof calldata proofRefund
    ) external;

    function setClaimPool(address claimPool) external;

    function burn(uint256 amount) external;
}
