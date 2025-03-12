// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockERC20.sol";

contract MockIchiV2 is MockERC20 {
    using SafeERC20 for IERC20;

    // ICHI V1 address
    address public ichiV1;

    // constant that represents 100%
    uint256 constant PERCENT = 100;

    // constant that represents difference in decimals between ICHI V1 and ICHI V2 tokens
    uint256 constant DECIMALS_DIFF = 1e9;

    constructor(address ichiV1_) MockERC20("ICHI", "ICHI", 18) {
        ichiV1 = ichiV1_;
    }

    /**
     * @notice Convert ICHI V1 tokens to ICHI V2 tokens
     * @param v1Amount The number of ICHI V1 tokens to be converted (using 9 decimals representation)
     */
    function convertToV2(uint256 v1Amount) external {
        require(v1Amount > 0, "IchiV2.convertToV2: amount must be > 0");

        // convert 9 decimals ICHI V1 to 18 decimals ICHI V2
        uint256 v2Amount = v1Amount * DECIMALS_DIFF;

        // transfer ICHI V1 tokens in
        IERC20(ichiV1).safeTransferFrom(msg.sender, address(this), v1Amount);

        _mint(msg.sender, v2Amount);
    }
}
