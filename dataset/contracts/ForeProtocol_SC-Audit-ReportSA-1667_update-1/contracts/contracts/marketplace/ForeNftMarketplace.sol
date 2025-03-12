// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../external/pancake-nft-markets/ERC721NFTMarketV1.sol";

contract ForeNftMarketplace is ERC721NFTMarketV1 {
    constructor(
        address _adminAddress,
        address _treasuryAddress,
        address _WBNBAddress,
        uint256 _minimumAskPrice,
        uint256 _maximumAskPrice
    )
        ERC721NFTMarketV1(
            _adminAddress,
            _treasuryAddress,
            _WBNBAddress,
            _minimumAskPrice,
            _maximumAskPrice
        )
    {}

    /**
     * @notice Override buyTokenUsingBNB to revert because its not used.
     */
    function buyTokenUsingBNB(
        address,
        uint256
    ) external payable virtual override {
        revert("ForeNftMarketplace: Function not implemented");
    }
}
