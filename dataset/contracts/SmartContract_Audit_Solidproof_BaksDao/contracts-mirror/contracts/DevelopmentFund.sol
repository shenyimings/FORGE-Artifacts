// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./libraries/SafeERC20.sol";
import {CoreInside, ICore} from "./Core.sol";
import {Governed} from "./Governance.sol";
import {IERC20} from "./interfaces/ERC20.sol";
import {Initializable} from "./libraries/Upgradability.sol";

/// @title Фонд развития
/// @author BaksDAO
contract DevelopmentFund is CoreInside, Initializable, Governed {
    using SafeERC20 for IERC20;

    function initialize(ICore _core) external initializer {
        initializeCoreInside(_core);
        setGovernor(msg.sender);
    }

    /// @dev Вывод BAKS.
    /// @param amount Сумма для вывода.
    function withdraw(uint256 amount) external onlyGovernor {
        IERC20(core.baks()).safeTransfer(msg.sender, amount);
    }
}
