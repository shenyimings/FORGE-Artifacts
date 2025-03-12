// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./IPlus.sol";

/**
 * @title Interface for composite plus token.
 * Composite plus is backed by a basket of plus with the same peg.
 */
interface ICompositePlus is IPlus {
    /**
     * @dev Returns the address of the underlying token.
     */
    function tokens(uint256 _index) external view returns (address);

    /**
     * @dev Checks whether a token is supported by the basket.
     */
    function tokenSupported(address _token) external view returns (bool);

     /**
     * @dev Mints composite plus tokens with underlying tokens provided.
     * @dev _tokens The tokens used to mint the composite plus token. The composite plus token must have sufficient allownance on the token.
     * @dev _amounts Amount of tokens used to mint the composite plus token.
     */
    function mint(address[] calldata _tokens, uint256[] calldata _amounts) external;

    /**
     * @dev Redeems the composite plus token. In the current implementation only proportional redeem is supported.
     * @param _amount Amount of composite plus token to redeem. -1 means redeeming all shares.
     */
    function redeem(uint256 _amount) external;
}