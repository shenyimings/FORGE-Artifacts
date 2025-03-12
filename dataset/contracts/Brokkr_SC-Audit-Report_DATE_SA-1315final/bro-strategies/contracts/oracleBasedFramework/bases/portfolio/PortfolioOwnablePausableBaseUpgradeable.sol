// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./PortfolioOwnableBaseUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

abstract contract PortfolioOwnablePausableBaseUpgradeable is
    PausableUpgradeable,
    PortfolioOwnableBaseUpgradeable
{
    uint256[4] private __gap;

    // solhint-disable-next-line
    function __PortfolioOwnablePausableBaseUpgradeable_init(
        PortfolioArgs calldata portfolioArgs
    ) internal onlyInitializing {
        __Pausable_init();
        __PortfolioOwnableBaseUpgradeable_init(portfolioArgs);
    }

    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    function deposit(
        uint256 depositTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address investmentTokenReceiver,
        NameValuePair[] calldata params
    ) public virtual override whenNotPaused {
        super._deposit(
            depositTokenAmountIn,
            minimumDepositTokenAmountOut,
            investmentTokenReceiver,
            params,
            false
        );
    }

    function withdraw(
        uint256 investmentTokenAmountIn,
        uint256 minimumDepositTokenAmountOut,
        address depositTokenReceiver,
        NameValuePair[] calldata params
    ) public virtual override whenNotPaused {
        super._withdraw(
            investmentTokenAmountIn,
            minimumDepositTokenAmountOut,
            depositTokenReceiver,
            params,
            true
        );
    }
}
