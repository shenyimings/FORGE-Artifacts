// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../interface/ICore.sol";
import "../../interface/IdETH.sol";

/**
 * @title Aspida's Strategy
 * @author Aspida engineer
 */
abstract contract StrategyBase {
    ICore internal immutable CORE;
    IdETH internal immutable DETH;

    constructor(ICore _core) {
        CORE = _core;
        DETH = IdETH(_core.dETH());
    }

    /**
     * @dev Throws if called by any account other than the core.
     */
    modifier onlyCore() {
        require(address(CORE) == msg.sender, "onlyCore: caller is not the core");
        _;
    }

    function strategyReceive() external payable virtual returns (uint256);

    function dETH() external view virtual returns (IdETH) {
        return DETH;
    }

    function core() external view virtual returns (ICore) {
        return CORE;
    }
}
