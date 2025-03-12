// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

import {IPerpetual} from "./IPerpetual.sol";

interface ISettlement {
    struct PnLProof {
        address account;
        int128 pnl;
        bytes32[] merkleProof;
    }

    /* ****************** */
    /*     Errors         */
    /* ****************** */

    error Settlement_InvalidMerkleProof();

    error Settlement_MustPostPositionProof();

    error Settlement_OpenPositionNotAllowed();

    error Settlement_ProvideLiquidityNotAllowed();

    error Settlement_RemoveLiquidityNotAllowed();

    error Settlement_ToggleTradingExpansionNotAllowed();

    error Settlement_SetParametersNotAllowed();

    /* ****************** */
    /*     Events         */
    /* ****************** */

    event MerkleRootUpdated(bytes32 oldMerkleRoot, bytes32 newMerkleRoot);

    event PositionVerified(address indexed account, int128 pnl, bytes32[] merkleProof);

    /* ****************** */
    /*     Views          */
    /* ****************** */

    function merkleRoot() external view returns (bytes32);

    function markets(uint256 i) external view returns (IPerpetual);

    function mustPostPosition(address account) external view returns (bool);

    function verifyPnL(PnLProof calldata userProof) external view returns (bool valid);

    /* ******************* */
    /*   State Modifying   */
    /* ******************* */

    function postPnL(PnLProof calldata userProof) external;

    function setMerkleRoot(bytes32 newMerkleRoot) external;
}
