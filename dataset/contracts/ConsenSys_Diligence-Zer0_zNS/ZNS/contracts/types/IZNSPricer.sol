// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


/**
 * @title IZNSPricer.sol
 * @notice Base interface required to be inherited by all Pricing contracts to work with zNS
 */
interface IZNSPricer {
    /**
     * @dev `parentHash` param is here to allow pricer contracts
     *  to have different price configs for different subdomains
     * `skipValidityCheck` param is added to provide proper revert when the user is
     * calling this to find out the price of a domain that is not valid. But in Registrar contracts
     * we want to do this explicitly and before we get the price to have lower tx cost for reverted tx.
     * So Registrars will pass this bool as "true" to not repeat the validity check.
     * Note that if calling this function directly to find out the price, a user should always pass "false"
     * as `skipValidityCheck` param, otherwise, the price will be returned for an invalid label that is not
     * possible to register.
     */
    function getPrice(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view returns (uint256);

    /**
     * @dev Fees are only supported for PaymentType.STAKE !
     *  This function will NOT be called if PaymentType != PaymentType.STAKE
     *  Instead `getPrice()` will be called.
     */
    function getPriceAndFee(
        bytes32 parentHash,
        string calldata label,
        bool skipValidityCheck
    ) external view returns (uint256 price, uint256 fee);

    /**
     * @notice Returns the fee for a given price.
     * @dev Fees are only supported for PaymentType.STAKE !
    */
    function getFeeForPrice(
        bytes32 parentHash,
        uint256 price
    ) external view returns (uint256);
}
