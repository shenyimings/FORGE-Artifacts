// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./IPoolAdapter.sol";

interface IAurigamiPool is IERC20Upgradeable {
    function mint(uint mintAmount) external;

    function redeem(uint redeemAmount) external;

    function redeemUnderlying(uint redeemAmount) external;

    function underlying() external view returns (address);

    function balanceOfUnderlying(address owner) external returns (uint);
}

interface IAurigamiComptroller {
    function enterMarkets(address[] memory auTokens) external;

    function claimReward(uint8 rewardType, address holder) external;

    function rewardAccrued(uint8 rewardType, address holder) external view returns (uint);

    function exitMarket(address auTokenAddress) external;

    function mintAllowed(
        address auToken,
        address minter,
        uint mintAmount
    ) external;
}

contract AurigamiPoolAdapter is IPoolAdapter {
    address private immutable comptrollerAddress;
    address private immutable plyAddress;
    bool private immutable rewards;

    constructor(
        address _comptrollerAddress,
        address _plyAddress,
        bool _rewards
    ) {
        comptrollerAddress = _comptrollerAddress;
        plyAddress = _plyAddress;
        rewards = _rewards;
    }

    function stakingBalance(address pool, bytes memory) external returns (uint256) {
        return IAurigamiPool(pool).balanceOfUnderlying(address(this));
    }

    function rewardBalance(address pool, bytes memory) external view returns (uint256) {
        if (rewards) {
            return IAurigamiComptroller(comptrollerAddress).rewardAccrued(0, address(this));
        }

        return 0;
    }

    function deposit(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        IERC20Upgradeable staked = IERC20Upgradeable(IAurigamiPool(pool).underlying());
        staked.approve(pool, amount);
        IAurigamiPool(pool).mint(amount);
        if (rewards) {
            enterMarket(pool);
        }
    }

    function withdraw(
        address pool,
        uint256 amount,
        bytes memory /* args */
    ) external {
        if (rewards) {
            exitMarket(pool);
        }

        IAurigamiPool(pool).redeemUnderlying(amount);

        if (rewards) {
            enterMarket(pool);
        }
    }

    function withdrawAll(
        address pool,
        bytes memory /* args */
    ) external {
        if (rewards) {
            exitMarket(pool);
        }

        IAurigamiPool(pool).redeem(IERC20Upgradeable(pool).balanceOf(address(this)));
    }

    function stakedToken(
        address pool,
        bytes memory /* args */
    ) public view returns (address) {
        return IAurigamiPool(pool).underlying();
    }

    function rewardToken(
        address pool,
        bytes memory /* args */
    ) public view returns (address) {
        if (rewards) {
            return plyAddress;
        }

        return address(0);
    }

    function enterMarket(address pool) private {
        address[] memory auTokens = new address[](1);
        auTokens[0] = pool;
        IAurigamiComptroller(comptrollerAddress).enterMarkets(auTokens);
    }

    function exitMarket(address pool) private {
        IAurigamiComptroller(comptrollerAddress).exitMarket(pool);
        IAurigamiComptroller(comptrollerAddress).claimReward(0, address(this));
    }
}
