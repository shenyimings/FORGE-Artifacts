// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity ^0.7.1;
pragma abicoder v2;
import { ABDKMath64x64 } from "abdk-libraries-solidity/ABDKMath64x64.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { BaseLock } from "./BaseLock.sol";

/// @title Locking a token for a collateral.
/// @author Victor Porton
/// @notice Not audited, not enough tested.
/// Lock a token to exchange it for a collateral in the future.
///
/// We have only one condition ID: `0`.
///
/// TODO: This contract is somehow gas-inefficient. Should we release it?
contract Lock is BaseLock {
    using ABDKMath64x64 for int128;

    struct ERC1155Token {
        IERC1155 contractAddress;
        uint256 tokenId;
    }

    /// Assign a token to an orcle
    /// @param oracleId The oracle ID.
    /// @param token The token.
    event OracleToken(uint64 indexed oracleId, ERC1155Token indexed token);

    /// Mapping (oracleId => external conditional token).
    mapping(uint64 => ERC1155Token) public externalConditionals;

    /// Constructor.
    /// @param _uri The ERC-1155 token URI.
    constructor(string memory _uri) BaseLock(_uri) { }

    /// Create a new oracle
    function createOracle(ERC1155Token calldata _token) external returns (uint64) {
        uint64 _oracleId = _createOracle();
        externalConditionals[_oracleId] = _token;
        emit OracleToken(_oracleId, _token);
        return _oracleId;
    }

    /// Mint a conditional token
    /// @param _oracleId The oracle ID.
    /// @param _conditionalTokenId The conditional token ID.
    /// @param _amount The minted amount.
    /// @param _data Additional data.
    function mintConditional(uint64 _oracleId, uint256 _conditionalTokenId, uint256 _amount, bytes calldata _data)
        public checkIsConditional(_conditionalTokenId)
    {
        ERC1155Token storage _externalConditional = externalConditionals[_oracleId];
        _mintToCustomer(msg.sender, _conditionalTokenId, _amount, _data);
        // Last against reentrancy attack:
        _externalConditional.contractAddress.safeTransferFrom(msg.sender, address(this), _externalConditional.tokenId, _amount, _data);
    }

    /// Burn a conditional token
    /// @param _oracleId The oracle ID.
    /// @param _conditionalTokenId The conditional token ID.
    /// @param _to The token recepient.
    /// @param _amount The minted amount.
    /// @param _data Additional data.
    function burnConditional(uint64 _oracleId, uint256 _conditionalTokenId, address _to, uint256 _amount, bytes calldata _data)
        public checkIsConditional(_conditionalTokenId)
    {
        ERC1155Token storage _externalConditional = externalConditionals[_oracleId];
        _burn(msg.sender, _conditionalTokenId, _amount);
        // Last against reentrancy attack:
        _externalConditional.contractAddress.safeTransferFrom(address(this), _to, _externalConditional.tokenId, _amount, _data);
    }

    function _calcRewardShare(uint64 /*oracleId*/, uint256 _condition)
        internal virtual override view returns (int128)
    {
        require(_condition == 1, "We support only one condition.");
        return int128(1).div(1);
    }

    // We have just one token, so the multiplier is one.
    function _calcMultiplier(uint64 /*oracleId*/, uint256 /*condition*/, int128 _oracleShare)
        internal virtual override view returns (int128)
    {
        return _oracleShare;
    }
}
