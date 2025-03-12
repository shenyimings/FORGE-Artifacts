// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/feeds/uniswapv3/IOverlayV1UniswapV3FeedFactory.sol";

import "../OverlayV1FeedFactory.sol";
import "./OverlayV1UniswapV3Feed.sol";

contract OverlayV1UniswapV3Factory is IOverlayV1UniswapV3FeedFactory, OverlayV1FeedFactory {
    address public immutable ovlWethPool;
    address public immutable ovl;

    // registry of feeds; for a given (pool, base, quote, amount) pair, returns associated feed
    mapping(address => mapping(address => mapping(address => mapping(uint128 => address))))
        public getFeed;

    constructor(
        address _ovlWethPool,
        address _ovl,
        uint256 _microWindow,
        uint256 _macroWindow
    ) OverlayV1FeedFactory(_microWindow, _macroWindow) {
        ovlWethPool = _ovlWethPool;
        ovl = _ovl;
    }

    /// @dev deploys a new feed contract
    /// @return feed_ address of the new feed
    function deployFeed(
        address marketPool,
        address marketBaseToken,
        address marketQuoteToken,
        uint128 marketBaseAmount
    ) external returns (address feed_) {
        require(
            getFeed[marketPool][marketBaseToken][marketQuoteToken][marketBaseAmount] == address(0),
            "OVLV1: feed already exists"
        );

        // Use the CREATE2 opcode to deploy a new Feed contract.
        // Will revert if feed which accepts (marketPool, marketBaseToken, marketQuoteToken,
        // marketBaseAmount) in its constructor has already been deployed since salt would be the
        // same and can't deploy with it twice.
        feed_ = address(
            new OverlayV1UniswapV3Feed{
                salt: keccak256(
                    abi.encode(marketPool, marketBaseToken, marketQuoteToken, marketBaseAmount)
                )
            }(
                marketPool,
                ovlWethPool,
                ovl,
                marketBaseToken,
                marketQuoteToken,
                marketBaseAmount,
                microWindow,
                macroWindow
            )
        );

        // store feed registry record for (marketPool, marketBaseToken, marketQuoteToken) combo
        // and record address as deployed feed
        getFeed[marketPool][marketBaseToken][marketQuoteToken][marketBaseAmount] = feed_;
        isFeed[feed_] = true;
        emit FeedDeployed(msg.sender, feed_);
    }
}
