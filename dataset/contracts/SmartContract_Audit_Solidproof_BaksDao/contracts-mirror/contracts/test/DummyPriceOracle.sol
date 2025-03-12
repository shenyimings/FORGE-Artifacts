// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./../interfaces/IPriceOracle.sol";
import "./../libraries/FixedPointMath.sol";
import {Governed} from "./../Governance.sol";
import {IERC20} from "./../interfaces/ERC20.sol";
import {Initializable} from "./../libraries/Upgradability.sol";
import {CoreInside, ICore} from "./../Core.sol";

contract DummyPriceOracle is CoreInside, Governed, Initializable, IPriceOracle {
    mapping(IERC20 => uint256) public prices;

    function initialize(ICore _core) external initializer {
        initializeCoreInside(_core);
        setGovernor(msg.sender);
    }

    function setPrice(IERC20 token, uint256 price) external onlyGovernor {
        prices[token] = price;
    }

    function getNormalizedPrice(IERC20 token) external view override returns (uint256 normalizedPrice) {
        normalizedPrice = prices[token];
    }
}
